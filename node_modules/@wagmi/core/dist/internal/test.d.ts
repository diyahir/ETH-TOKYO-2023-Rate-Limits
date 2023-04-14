import '../index-35b6525c.js';
import { Wallet, providers } from 'ethers';
import { Chain } from '@wagmi/chains';
import '@wagmi/connectors';
import 'abitype';

declare const testChains: (Chain | {
    readonly id: 5;
    readonly network: "goerli";
    readonly name: "Goerli";
    readonly nativeCurrency: {
        readonly name: "Goerli Ether";
        readonly symbol: "ETH";
        readonly decimals: 18;
    };
    readonly rpcUrls: {
        readonly alchemy: {
            readonly http: readonly ["https://eth-goerli.g.alchemy.com/v2"];
            readonly webSocket: readonly ["wss://eth-goerli.g.alchemy.com/v2"];
        };
        readonly infura: {
            readonly http: readonly ["https://goerli.infura.io/v3"];
            readonly webSocket: readonly ["wss://goerli.infura.io/ws/v3"];
        };
        readonly default: {
            readonly http: readonly ["https://rpc.ankr.com/eth_goerli"];
        };
        readonly public: {
            readonly http: readonly ["https://rpc.ankr.com/eth_goerli"];
        };
    };
    readonly blockExplorers: {
        readonly etherscan: {
            readonly name: "Etherscan";
            readonly url: "https://goerli.etherscan.io";
        };
        readonly default: {
            readonly name: "Etherscan";
            readonly url: "https://goerli.etherscan.io";
        };
    };
    readonly contracts: {
        readonly ensRegistry: {
            readonly address: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e";
        };
        readonly ensUniversalResolver: {
            readonly address: "0xA292E2E58d4ddEb29C33c63173d0E8B7a2A4c62e";
            readonly blockCreated: 8610406;
        };
        readonly multicall3: {
            readonly address: "0xca11bde05977b3631167028862be2a173976ca11";
            readonly blockCreated: 6507670;
        };
    };
    readonly testnet: true;
} | {
    readonly id: 1;
    readonly network: "homestead";
    readonly name: "Ethereum";
    readonly nativeCurrency: {
        readonly name: "Ether";
        readonly symbol: "ETH";
        readonly decimals: 18;
    };
    readonly rpcUrls: {
        readonly alchemy: {
            readonly http: readonly ["https://eth-mainnet.g.alchemy.com/v2"];
            readonly webSocket: readonly ["wss://eth-mainnet.g.alchemy.com/v2"];
        };
        readonly infura: {
            readonly http: readonly ["https://mainnet.infura.io/v3"];
            readonly webSocket: readonly ["wss://mainnet.infura.io/ws/v3"];
        };
        readonly default: {
            readonly http: readonly ["https://cloudflare-eth.com"];
        };
        readonly public: {
            readonly http: readonly ["https://cloudflare-eth.com"];
        };
    };
    readonly blockExplorers: {
        readonly etherscan: {
            readonly name: "Etherscan";
            readonly url: "https://etherscan.io";
        };
        readonly default: {
            readonly name: "Etherscan";
            readonly url: "https://etherscan.io";
        };
    };
    readonly contracts: {
        readonly ensRegistry: {
            readonly address: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e";
        };
        readonly ensUniversalResolver: {
            readonly address: "0xE4Acdd618deED4e6d2f03b9bf62dc6118FC9A4da";
            readonly blockCreated: 16773775;
        };
        readonly multicall3: {
            readonly address: "0xca11bde05977b3631167028862be2a173976ca11";
            readonly blockCreated: 14353601;
        };
    };
} | {
    readonly id: 10;
    readonly name: "Optimism";
    readonly network: "optimism";
    readonly nativeCurrency: {
        readonly name: "Ether";
        readonly symbol: "ETH";
        readonly decimals: 18;
    };
    readonly rpcUrls: {
        readonly alchemy: {
            readonly http: readonly ["https://opt-mainnet.g.alchemy.com/v2"];
            readonly webSocket: readonly ["wss://opt-mainnet.g.alchemy.com/v2"];
        };
        readonly infura: {
            readonly http: readonly ["https://optimism-mainnet.infura.io/v3"];
            readonly webSocket: readonly ["wss://optimism-mainnet.infura.io/ws/v3"];
        };
        readonly default: {
            readonly http: readonly ["https://mainnet.optimism.io"];
        };
        readonly public: {
            readonly http: readonly ["https://mainnet.optimism.io"];
        };
    };
    readonly blockExplorers: {
        readonly etherscan: {
            readonly name: "Etherscan";
            readonly url: "https://optimistic.etherscan.io";
        };
        readonly default: {
            readonly name: "Optimism Explorer";
            readonly url: "https://explorer.optimism.io";
        };
    };
    readonly contracts: {
        readonly multicall3: {
            readonly address: "0xca11bde05977b3631167028862be2a173976ca11";
            readonly blockCreated: 4286263;
        };
    };
} | {
    readonly id: 137;
    readonly name: "Polygon";
    readonly network: "matic";
    readonly nativeCurrency: {
        readonly name: "MATIC";
        readonly symbol: "MATIC";
        readonly decimals: 18;
    };
    readonly rpcUrls: {
        readonly alchemy: {
            readonly http: readonly ["https://polygon-mainnet.g.alchemy.com/v2"];
            readonly webSocket: readonly ["wss://polygon-mainnet.g.alchemy.com/v2"];
        };
        readonly infura: {
            readonly http: readonly ["https://polygon-mainnet.infura.io/v3"];
            readonly webSocket: readonly ["wss://polygon-mainnet.infura.io/ws/v3"];
        };
        readonly default: {
            readonly http: readonly ["https://polygon-rpc.com"];
        };
        readonly public: {
            readonly http: readonly ["https://polygon-rpc.com"];
        };
    };
    readonly blockExplorers: {
        readonly etherscan: {
            readonly name: "PolygonScan";
            readonly url: "https://polygonscan.com";
        };
        readonly default: {
            readonly name: "PolygonScan";
            readonly url: "https://polygonscan.com";
        };
    };
    readonly contracts: {
        readonly multicall3: {
            readonly address: "0xca11bde05977b3631167028862be2a173976ca11";
            readonly blockCreated: 25770160;
        };
    };
})[];
declare class WalletSigner extends Wallet {
    connectUnchecked(): providers.JsonRpcSigner;
}
declare function getSigners(): WalletSigner[];

export { getSigners, testChains };
