// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract VeelancingToken is ERC20, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant INVESTOR_ROLE = keccak256("INVESTOR_ROLE");
    bytes32 public constant TEAM_ROLE = keccak256("TEAM_ROLE");
    uint256 private percIco;
    uint256 private percPreIco;
    uint256 public constant basePrice = 100 * 10**18;
    uint256 private icoCap;
    uint256 private soldIcoTotal;
    uint256 private endIcoDate;
    uint256 private vestingPerc;
    uint256 private vestingDays;
    address[] private investors;
    uint256[] private investorAmounts;
    uint256 private percInvestors;
    uint256 private vestingDaysInvestors;
    address[] private team;
    uint256[] private teamAmounts;
    uint256 private percTeam;
    uint256 private vestingDaysTeam;

    enum CrowdState {
        NotStarted,
        PreICO,
        ICO,
        Finished
    }

    struct VestedBalance {
        mapping(uint256 => uint256) perc;
        uint256 balance;
        uint256 initialBalance;
    }

    mapping(address => VestedBalance) private _vestedBalances;

    CrowdState private state;

    event WithdrawFromVested(address indexed to, uint256 value);
    event DepositToVested(address indexed to, uint256 value);
    event Deposit(address indexed to, uint256 value);

    constructor(
        string memory name,
        string memory symbol,
        address Liquidity,
        uint256 volume_liquidity,
        uint256 percIco_,
        uint256 percPreIco_,
        uint256 icoCap_,
        address owner
    ) public ERC20(name, symbol) {
        percIco = percIco_;
        percPreIco = percPreIco_;
        icoCap = icoCap_;

        soldIcoTotal = 0;

        state = CrowdState.NotStarted;

        vestingDays = 90 days;
        vestingPerc = 20;

        team = [0x81cC9eCaD6a8D9367B18Ad892d5f7dD1212010A7];
        teamAmounts = [1000000];
        percTeam = 30;
        vestingDaysTeam = 120 days;

        investors = [0x81cC9eCaD6a8D9367B18Ad892d5f7dD1212010A7];
        investorAmounts = [10000];
        percInvestors = 25;
        vestingDaysInvestors = 180 days;

        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, owner);
        depositToVested(Liquidity, volume_liquidity);

        for (uint256 i = 0; i < investors.length; i++) {
            _setupRole(INVESTOR_ROLE, investors[i]);
            depositToVested(investors[i], investorAmounts[i]);
        }

        for (uint256 i = 0; i < team.length; i++) {
            _setupRole(TEAM_ROLE, team[i]);
            depositToVested(team[i], teamAmounts[i]);
        }
    }

    function getIcoCap() public returns (uint256) {
        return icoCap;
    }

    function getIcoSold() public returns (uint256) {
        return soldIcoTotal;
    }

    function getCurrentStatus() public returns (string memory) {
        if (state == CrowdState.NotStarted) {
            return "NotStarted";
        } else if (state == CrowdState.PreICO) {
            return "Pre ICO";
        } else if (state == CrowdState.ICO) {
            return "ICO";
        } else {
            return "Finished";
        }
    }

    function getVestedAllowedPerc(address to) public virtual returns (uint256) {
        uint256 date = endIcoDate;
        uint256 perc = 0;

        if (state != CrowdState.Finished) {
            return 0;
        }

        do {
            if (hasRole(TEAM_ROLE, to)) {
                perc = perc.add(percTeam);
                date = date.add(vestingDaysTeam);
            } else if (hasRole(INVESTOR_ROLE, to)) {
                perc = perc.add(percInvestors);
                date = date.add(vestingDaysInvestors);
            } else {
                perc = perc.add(vestingPerc);
                date = date.add(vestingDays);
            }
        } while (date < block.timestamp && perc <= 100);

        return perc;
    }

    function getVestedTotalBalance(address to)
        public
        virtual
        returns (uint256)
    {
        uint256 consumed;

        for (uint256 index = 10; index <= 100; index += 10) {
            consumed = consumed.add(_vestedBalances[to].perc[index]);
        }

        uint256 total = _vestedBalances[to].initialBalance;

        return total.sub(consumed);
    }

    function getVestedAllowedBalance(address to)
        public
        virtual
        returns (uint256)
    {
        uint256 perc = getVestedAllowedPerc(to);

        uint256 total = _vestedBalances[to].initialBalance.div(100).mul(perc);
        uint256 consumed = _vestedBalances[to].perc[perc];

        return total.sub(consumed);
    }

    function withdrawFromVested(uint256 amount) public virtual {
        uint256 perc = getVestedAllowedPerc(_msgSender());
        uint256 balance = _vestedBalances[_msgSender()]
            .initialBalance
            .div(100)
            .mul(perc)
            .sub(_vestedBalances[_msgSender()].perc[perc]);

        require(
            amount <= balance,
            "Veelancing: withdraw amount exceeds balance"
        );

        _vestedBalances[_msgSender()].balance = _vestedBalances[_msgSender()]
            .balance
            .sub(amount);
        _vestedBalances[_msgSender()].perc[perc] = _vestedBalances[_msgSender()]
            .perc[perc]
            .add(amount);
        _mint(_msgSender(), amount);
        emit WithdrawFromVested(_msgSender(), amount);
    }

    function depositToVested(address recipient, uint256 amount) public virtual {
        _vestedBalances[recipient].initialBalance = _vestedBalances[recipient]
            .initialBalance
            .add(amount);
        _vestedBalances[recipient].balance = _vestedBalances[recipient]
            .balance
            .add(amount);
        emit DepositToVested(recipient, amount);
    }

    function deposit(address recipient, uint256 amount) public virtual {
        uint256 total = amount;

        if (state == CrowdState.PreICO) {
            total = total.mul(percPreIco).div(100).add(total);

            require(
                soldIcoTotal.add(total) <= icoCap,
                "Veelancing: ICO Cap excedeed"
            );

            soldIcoTotal = soldIcoTotal.add(total);

            depositToVested(recipient, total);
        } else {
            if (state == CrowdState.ICO) {
                total = total.mul(percIco).div(100).add(total);

                require(
                    soldIcoTotal.add(total) <= icoCap,
                    "Veelancing: ICO Cap excedeed"
                );

                soldIcoTotal = soldIcoTotal.add(total);
            }

            _mint(recipient, total);
            emit Deposit(recipient, total);
        }
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override(ERC20)
        returns (bool)
    {
        if (!hasRole(ADMIN_ROLE, _msgSender())) {
            require(state == CrowdState.Finished, "Veelancing: ICO season");
        }

        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function startPreIco() public virtual {
        require(
            hasRole(ADMIN_ROLE, _msgSender()),
            "Veelancing: Only the admin can start the Pre ICO"
        );
        state = CrowdState.PreICO;
    }

    function startIco() public virtual {
        require(
            hasRole(ADMIN_ROLE, _msgSender()),
            "Veelancing: Only the admin can start the ICO"
        );
        state = CrowdState.ICO;
    }

    function endIco() public virtual {
        require(state == CrowdState.ICO, "Veelancing: ICO already ended.");
        require(
            hasRole(ADMIN_ROLE, _msgSender()),
            "Veelancing: Only the admin can end the ICO"
        );

        uint256 leftTokens = icoCap.sub(soldIcoTotal);
        state = CrowdState.Finished;
        endIcoDate = block.timestamp;

        if (leftTokens > 0) {
            deposit(_msgSender(), leftTokens);
        }
    }

    receive() external payable virtual {
        uint256 weiAmount = msg.value;
        uint256 tokens = weiAmount.mul(basePrice).div(1 ether);
        deposit(_msgSender(), tokens);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
