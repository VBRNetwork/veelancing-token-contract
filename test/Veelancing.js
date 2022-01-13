const Veelancing = artifacts.require("VeelancingToken");
const Web3 = require("web3");
require("dotenv").config();
const web3 = new Web3(`https://127.0.0.1:7545`);
const { ethers } = require("ethers");

contract("Veelancing", (accounts) => {
	it("should call a function that depends on a linked library", () => {
		let meta;
		let metaCoinBalance;
		let metaCoinEthBalance;

		return Veelancing.deployed()
			.then((instance) => {
				meta = instance;
				return meta.balanceOf.call(accounts[0]);
			})
			.then((outCoinBalance) => {
				metaCoinBalance = BigInt(outCoinBalance);
				return meta.balanceOf.call(accounts[0]);
			})
			.then((outCoinBalanceEth) => {
				metaCoinEthBalance = BigInt(outCoinBalanceEth);
			})
			.then(() => {
				console.log(metaCoinEthBalance, metaCoinBalance);
				assert.equal(
					metaCoinEthBalance,
					metaCoinBalance,
					"Library function returned unexpected function, linkage may be broken"
				);
			});
	});

	it("should send coin correctly", async () => {
		let meta;

		// Get initial balances of first and second account.
		const [account_one, account_two, account_three] = accounts;

		let account_one_starting_balance;
		let account_two_starting_balance;
		let account_one_ending_balance;
		let account_two_ending_balance;

		const amount = 100;

		console.log(account_one, account_two, account_three);

		const contract = await Veelancing.deployed(
			"Veelancing Token",
			"SLBZ",
			account_one,
			500,
			20,
			100000000000,
			100000000000000000,
			account_one
		);
		await contract.startPreIco.sendTransaction({
			from: "0x4d1c48F16CdF20aBeA99DbD9761641d4ba82bE8d",
		});
		await contract.startIco.sendTransaction({
			from: "0x4d1c48F16CdF20aBeA99DbD9761641d4ba82bE8d",
		});
		console.log(await contract.getCurrentStatus.call());

		await contract.sendTransaction({
			from: account_two,
			value: web3.utils.toWei("0.0001", "ether"),
		});

		let balance_2 = BigInt(
			await contract.getVestedAllowedBalance.call(account_two)
		);

		console.log(balance_2);

		balance_2 = BigInt(await contract.balanceOf.call(account_two));

		await contract.endIco.sendTransaction({
			from: "0x4d1c48F16CdF20aBeA99DbD9761641d4ba82bE8d",
		});

		console.log(BigInt(await contract.getVestedAllowedPerc.call(account_two)));

		balance_2 = BigInt(
			await contract.getVestedAllowedBalance.call(account_two)
		);
		console.log(balance_2);

		await contract.withdrawFromVested(1500000000000000, {
			from: account_two,
		});

		balance_2 = BigInt(await contract.balanceOf.call(account_two));

		console.log(balance_2);

		balance_2 = BigInt(
			await contract.getVestedAllowedBalance.call(account_two)
		);
		console.log(balance_2);

		await contract.deposit(account_two, 800, {
			from: account_two,
		});
		balance_2 = BigInt(await contract.balanceOf.call(account_two));
		console.log(balance_2);
		console.log(
			BigInt(await contract.getIcoSold.call()),
			BigInt(await contract.getIcoCap.call())
		);

		console.log(await contract.getCurrentStatus.call());

		await contract.transfer(
			"0x4d1c48F16CdF20aBeA99DbD9761641d4ba82bE8d",
			amount,
			{ from: account_two }
		);

		const balance_1 = BigInt(
			await contract.balanceOf.call(
				"0x4d1c48F16CdF20aBeA99DbD9761641d4ba82bE8d"
			)
		);
		balance_2 = BigInt(await contract.balanceOf.call(account_two));

		console.log(balance_1, balance_2, amount);

		assert.equal(
			balance_2,
			BigInt(amount * 2),
			"Amount wasn't correctly taken from the sender"
		);
	});
});
