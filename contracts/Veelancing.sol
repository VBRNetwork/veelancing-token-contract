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
    bytes32 public constant BONUS_ICO_ROLE = keccak256("BONUS_ICO_ROLE");
    uint256 private percIco;
    uint256 private percPreIco;
    uint256 public constant basePrice = 100 * 10**18;
    uint256 private icoCap;
    uint256 private soldIcoTotal;
    uint256 private endIcoDate;
    uint256 private cap;

    uint256 private constant vestingPerc = 20;
    uint256 private constant vestingDays = 90 days;
    address[] private constant investors = [
        0xc9c4aAf0042dAa49e404bdB5a84EfcFc17c54880,
        0x72321DEc1Bc93D8C906E40d1056522283A4389F9,
        0xB2BD39587cf589AAAb6a36e25B0aED76FCf58c7B,
        0x3EfFeC8EbcF00052F62e4001B7804011Da7c6f14
    ];
    uint256[] private constant investorAmounts = [
        40010,
        12500000,
        38940,
        39640
    ];
    uint256 private constant percInvestors = 25;
    uint256 private constant vestingDaysInvestors = 180 days;
    address[] private constant team = [
        0xF553CE9e38b21077f518D8dB39dB892f05751FA1,
        0xdA974670f0Fa770db9277A0306d568E4D6f6c5a3,
        0x23922042557AF5B562eab49FD0AC09b16E6Ac5E2,
        0xA0e6f859c24549Efc0f873e7e5c043d90bA68EAb,
        0x733ACd147e486cBe9f33257DC6272Ad5292a8E6f,
        0x700Ff631E391E22F8B7C97051626f98ff4AE2123,
        0x6C7CCd2c0f29FE4a01f834E98a97e3698C7Ee168,
        0xb02dbF9e04535cf3f086fE812BF765D9A8ECE5dB,
        0xa7d4301F1F5F1C5Ac2Dcc2e761b04Fcbe0bA1Fed,
        0xC9d8fB40f6d0E3e14C36B93e66EC16C9d4F70ed3,
        0x72e8BBe74a17dfa47533e556189152f174A00ED9,
        0x81a806E845D80bc775D721878d976e6F20dfA115,
        0xBdB1D0e82620bf90a7B231b19c69caD391073341,
        0xAc531927bD88c9A59e757Cb5BB556535c9c3043F,
        0x2BC800abE1bd22beC07561Bc7405209088977169
    ];
    uint256[] private constant teamAmounts = [
        20000270,
        6000960,
        30000300,
        7000000,
        7000000,
        7000000,
        3000000,
        50000,
        7000000,
        7000000,
        6000000,
        7000100,
        5100,
        1100,
        7000100
    ];
    uint256 private constant percTeam = 30;
    uint256 private constant vestingDaysTeam = 120 days;
    uint256 private constant percBonusIco = 20;
    uint256 private constant vestingDaysBonusIco = 240 days;

    enum CrowdState {
        NotStarted,
        PreICO,
        ICO,
        Finished
    }

    enum WalletStatus {
        Blocked,
        Unblocked
    }

    struct VestedBalance {
        mapping(uint256 => uint256) perc;
        uint256 balance;
        uint256 initialBalance;
    }

    mapping(address => VestedBalance) private _vestedBalances;
    mapping(address => WalletStatus) private _blockedWallets;

    CrowdState private state;

    event WithdrawFromVested(address indexed to, uint256 value);
    event DepositToVested(address indexed to, uint256 value);
    event WalletStatusChanged(address indexed to, WalletStatus status);
    event Deposit(address indexed to, uint256 value);
    event CapIncreased(uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        address Liquidity,
        uint256 volume_liquidity,
        uint256 percIco_,
        uint256 percPreIco_,
        uint256 icoCap_,
        uint256 cap_,
        address owner
    ) public ERC20(name, symbol) {
        percIco = percIco_;
        percPreIco = percPreIco_;
        icoCap = icoCap_;
        cap = cap_;

        soldIcoTotal = 0;

        state = CrowdState.NotStarted;

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

    function getCap() public view virtual returns (uint256) {
        return cap;
    }

    function increaseCap(uint256 amount) public virtual {
        require(
            hasRole(ADMIN_ROLE, _msgSender()),
            "Veelancing: Only admin can increase the cap"
        );
        cap = cap.add(amount);
        emit CapIncreased(amount);
    }

    function getIcoCap() public view returns (uint256) {
        return icoCap;
    }

    function getIcoSold() public view returns (uint256) {
        return soldIcoTotal;
    }

    function getCurrentStatus() public view returns (string memory) {
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
            if (hasRole(BONUS_ICO_ROLE, to)) {
                perc = perc.add(percBonusIco);
                date = date.add(vestingDaysBonusIco);
            } else if (hasRole(TEAM_ROLE, to)) {
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
        view
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

    function getWalletStatus(address recipient)
        public
        view
        returns (WalletStatus)
    {
        return _blockedWallets[recipient];
    }

    function setWalletStatus(address recipient, WalletStatus status) public {
        require(
            hasRole(ADMIN_ROLE, _msgSender()),
            "Veelancing: Only the admin can change the wallet status"
        );

        _blockedWallets[recipient] = status;
        emit WalletStatusChanged(recipient, status);
    }

    function deposit(address recipient, uint256 amount) public virtual {
        uint256 total = amount;

        if (state == CrowdState.PreICO) {
            total = total.mul(percPreIco).div(100).add(total);

            require(
                soldIcoTotal.add(total) <= icoCap,
                "Veelancing: ICO Cap excedeed"
            );

            if (getWalletStatus(recipient) == WalletStatus.Unblocked) {
                setWalletStatus(recipient, WalletStatus.Blocked);
            }

            soldIcoTotal = soldIcoTotal.add(total);

            depositToVested(recipient, total);
        } else {
            if (state == CrowdState.ICO) {
                total = total.mul(percIco).div(100).add(total);

                require(
                    soldIcoTotal.add(total) <= icoCap,
                    "Veelancing: ICO Cap excedeed"
                );

                if (getWalletStatus(recipient) == WalletStatus.Unblocked) {
                    setWalletStatus(recipient, WalletStatus.Blocked);
                }

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

        require(
            getWalletStatus(_msgSender()) == WalletStatus.Unblocked,
            "Veelancing: Wallet is blocked"
        );

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

    function createBonus(address recipient, uint256 amount) public virtual {
        require(
            hasRole(ADMIN_ROLE, _msgSender()),
            "Veelancing: Only the admin can create bonuses"
        );

        _setupRole(BONUS_ICO_ROLE, recipient);
        depositToVested(recipient, amount);
        soldIcoTotal = soldIcoTotal.add(amount);
    }

    receive() external payable virtual {
        uint256 weiAmount = msg.value;
        uint256 tokens = weiAmount.mul(basePrice).div(1 ether);
        deposit(_msgSender(), tokens);
    }

    function _mint(address account, uint256 amount) internal virtual override {
        require(
            totalSupply().add(amount) <= getCap(),
            "Veelancing: Cap exceeded"
        );
        super._mint(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
