var Veelancing = artifacts.require("VeelancingToken");
require("dotenv").config();

module.exports = async function (deployer) {
	const contract = await deployer.deploy(
		Veelancing,
		process.env.NAME,
		process.env.SYMBOL,
		process.env.ADDRESS_LIQUIDITY,
		process.env.VOLUME_LIQUIDITY,
		process.env.ICO_PERCENT_BONUS,
		process.env.PREICO_PERCENT_BONUS,
		process.env.ICO_CAP,
		process.env.ADMIN_ADDRESS
	);

	// console.log(deployer);
	// const res = await contract.deposit.sendTransaction(
	// 	"0x4d21c4285454a36D92a7E20C2A7199b5a007eAAE",
	// 	200
	// );
	// console.log(res);

	// const balance = await contract.balanceOf.call(
	// 	"0x4d21c4285454a36D92a7E20C2A7199b5a007eAAE"
	// );
	// console.log(balance.toNumber());
};
