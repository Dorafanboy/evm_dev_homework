const { ethers } = require("hardhat");

async function main() {
    console.log("Deploying PancakeSwapTrader...\n");

    const [deployer] = await ethers.getSigners();
    
    console.log("Deploying with account:", deployer.address);
    console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()), "BNB\n");

    const PANCAKE_ROUTER_ADDRESSES = {
        bsc: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
        bscTestnet: "0xD99D1c33F9fC3444f8101754aBC46c52416550D1",
    };

    const network = await ethers.provider.getNetwork();
    let routerAddress;
    let networkName;

    switch (network.chainId) {
        case 56:
            routerAddress = PANCAKE_ROUTER_ADDRESSES.bsc;
            networkName = "BSC Mainnet";
            break;
        case 97:
            routerAddress = PANCAKE_ROUTER_ADDRESSES.bscTestnet;
            networkName = "BSC Testnet";
            break;
        default:
            throw new Error(`Unsupported network: ${network.chainId}`);
    }

    console.log(`Deploying to ${networkName} (Chain ID: ${network.chainId})`);
    console.log(`Router address: ${routerAddress}\n`);

    console.log("Deploying contract...");
    const PancakeSwapTrader = await ethers.getContractFactory("PancakeSwapTrader");
    const trader = await PancakeSwapTrader.deploy(routerAddress);

    console.log("Waiting for deployment...");
    await trader.deployed();

    console.log("✅ Contract deployed successfully!");
    console.log("Contract Address:", trader.address);
    console.log("Router address used:", routerAddress);

    console.log("\n" + "=".repeat(50));
    console.log("CONTRACT INFORMATION");
    console.log("=".repeat(50));
    console.log("Contract Address:", trader.address);
    console.log("Owner:", await trader.owner());
    console.log("Router:", await trader.pancakeRouter());
    console.log("Factory:", await trader.pancakeFactory());
    console.log("WBNB:", await trader.WBNB());
    
    const contractBalance = await trader.getBNBBalance();
    console.log("Contract BNB Balance:", ethers.utils.formatEther(contractBalance), "BNB");

    console.log("\n" + "=".repeat(50));
    console.log("DEPLOYMENT COMPLETED");
    console.log("=".repeat(50));

    console.log("\nUSAGE EXAMPLES:");
    console.log("=".repeat(30));
    
    if (network.chainId === 56) {
        console.log("await trader.buyTokensExact(\"0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82\", ethers.utils.parseEther(\"100\"), deadline, {value: ethers.utils.parseEther(\"0.1\")});");
    } else {
        console.log("await trader.buyTokensExact(\"0xFa60D973F7642B748046464e165A65B7323b0DEE\", ethers.utils.parseEther(\"100\"), deadline, {value: ethers.utils.parseEther(\"0.1\")});");
    }

    console.log("await trader.swapAndAddLiquidity(tokenAddress, ethers.utils.parseEther(\"1000\"), 50, deadline, {value: ethers.utils.parseEther(\"0.5\")});");

    console.log("\nLinks:");
    if (network.chainId === 56) {
        console.log("BSCScan:", `https://bscscan.com/address/${trader.address}`);
        console.log("PancakeSwap:", "https://pancakeswap.finance/");
    } else {
        console.log("BSCScan Testnet:", `https://testnet.bscscan.com/address/${trader.address}`);
        console.log("PancakeSwap Testnet:", "https://pancakeswap.finance/");
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Deployment failed:");
        console.error(error);
        process.exit(1);
    }); 