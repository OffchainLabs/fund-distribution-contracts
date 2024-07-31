import { JsonRpcProvider } from "@ethersproject/providers";
import { DoubleProvider } from "../template/util";

export type chainID = 42161 | 42170;
enum FeeType {
  L1_BASE = "L1 Base",
  L1_SUPRPLUS = "L1 Surplus",
  L2_BASE = "L2 Base",
  L2_SUPRPLUS = "L2 Surplus",
}

interface Chain {
  id: chainID;
  name: string;
  startBlock: number;
  provider: DoubleProvider;
}
interface RewardDistributorData {
  address: string;
  chain: Chain;
  feeType: FeeType;
}

const arbOne: Chain = {
  id: 42161,
  name: "Arbitum One",
  startBlock: 70483300,
  provider: new DoubleProvider("https://arb1.arbitrum.io/rpc"),
};

const nova: Chain = {
  id: 42170,
  name: "Arbitum Nova",
  startBlock: 3162000,
  provider: new DoubleProvider("https://nova.arbitrum.io/rpc"),
};
export const rewardDistributors: RewardDistributorData[] = [
  {
    address: "0xE6ec2174539a849f9f3ec973C66b333eD08C0c18",
    chain: arbOne,
    feeType: FeeType.L1_BASE,
  },
  {
    address: "0x2E041280627800801E90E9Ac83532fadb6cAd99A",
    chain: arbOne,
    feeType: FeeType.L1_SUPRPLUS,
  },
  {
    address: "0xbF5041Fc07E1c866D15c749156657B8eEd0fb649",
    chain: arbOne,
    feeType: FeeType.L2_BASE,
  },
  {
    address: "0x32e7AF5A8151934F3787d0cD59EB6EDd0a736b1d",
    chain: arbOne,
    feeType: FeeType.L2_SUPRPLUS,
  },
  {
    address: "0xc9722CfDDFbC6aF4E77023E8B5Bd87489EFEbf5F",
    chain: nova,
    feeType: FeeType.L1_BASE,
  },
  {
    address: "0x509386DbF5C0BE6fd68Df97A05fdB375136c32De",
    chain: nova,
    feeType: FeeType.L1_SUPRPLUS,
  },
  {
    address: "0x9fCB6F75D99029f28F6F4a1d277bae49c5CAC79f",
    chain: nova,
    feeType: FeeType.L2_BASE,
  },
  {
    address: "0x3B68a689c929327224dBfCe31C1bf72Ffd2559Ce",
    chain: nova,
    feeType: FeeType.L2_SUPRPLUS,
  },
];
