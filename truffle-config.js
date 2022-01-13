require("dotenv").config();
const HDWalletProvider = require("@truffle/hdwallet-provider");
module.exports = {
	networks: {
		rinkeby: {
			provider: function () {
				return new HDWalletProvider(
					[process.env.PRIVATE_KEY],
					`https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`
				);
			},
			from: process.env.ETH_STORAGE,
			network_id: 4,
			gas: 4500000,
			gasPrice: 10000000000,
			skipDryRun: true,
		},
		aurora: {
			provider: function () {
				return new HDWalletProvider(
					[process.env.PRIVATE_KEY],
					`https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`
				);
			},
			from: process.env.ETH_STORAGE,
			network_id: 4,
			gas: 4500000,
			gasPrice: 10000000000,
			skipDryRun: true,
		},
		development: {
			host: "127.0.0.1",
			port: 7545,
			network_id: 5777,
		},
	},

	mocha: {
		// timeout: 100000
	},
	compilers: {
		solc: {
			version: "0.8.11",
			settings: {
				optimizer: {
					enabled: false,
					runs: 200,
				},
			},
		},
	},
	db: {
		enabled: false,
	},
};
