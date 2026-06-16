// Helpers that stand in for the op-proposer / op-challenger that supersim does
// not run. They let the e2e test drive an L2->L1 withdrawal to completion:
//
//   1. createDisputeGame  - post the real L2 output root as a dispute game,
//                           impersonating the permissioned proposer
//   2. (test proves via the redeemer)
//   3. resolveGame        - fast-forward past the game clock and resolve it
//                           DEFENDER_WINS
//   4. warp               - fast-forward past the portal proof-maturity /
//                           dispute-game-finality delays
//   5. (test finalizes via the redeemer)
//
// Everything relies on the L1 being an anvil node (supersim), so we can
// impersonate accounts and warp time.

import {
  AbiCoder,
  Contract,
  Interface,
  JsonRpcProvider,
  Signer,
  ZeroHash,
  keccak256,
  toBeHex,
} from 'ethers'

const L2_TO_L1_MESSAGE_PASSER = '0x4200000000000000000000000000000000000016'

const factoryAbi = [
  'function create(uint32 gameType, bytes32 rootClaim, bytes extraData) payable returns (address)',
  'function gameCount() view returns (uint256)',
  'function gameAtIndex(uint256) view returns (uint32 gameType, uint64 timestamp, address proxy)',
]

const gameAbi = [
  'function maxClockDuration() view returns (uint64)',
  'function resolveClaim(uint256 claimIndex, uint256 numToResolve)',
  'function resolve() returns (uint8)',
  'function status() view returns (uint8)',
]

// Output root committed to by a dispute game's root claim:
// keccak256(version, stateRoot, messagePasserStorageRoot, latestBlockhash)
async function computeL2OutputRoot(
  l2: JsonRpcProvider,
  l2BlockNumber: number
): Promise<string> {
  const blockTag = toBeHex(l2BlockNumber)
  const block = await l2.send('eth_getBlockByNumber', [blockTag, false])
  const proof = await l2.send('eth_getProof', [
    L2_TO_L1_MESSAGE_PASSER,
    [],
    blockTag,
  ])
  return keccak256(
    AbiCoder.defaultAbiCoder().encode(
      ['bytes32', 'bytes32', 'bytes32', 'bytes32'],
      [ZeroHash, block.stateRoot, proof.storageHash, block.hash]
    )
  )
}

// Posts a permissioned dispute game whose root claim is the output root at
// l2BlockNumber, so a withdrawal at or before that block can be proven.
// Returns the game proxy address.
export async function createDisputeGame(
  l1: JsonRpcProvider,
  l2: JsonRpcProvider,
  factoryAddr: string,
  proposer: string,
  l2BlockNumber: number
): Promise<string> {
  const rootClaim = await computeL2OutputRoot(l2, l2BlockNumber)
  const extraData = AbiCoder.defaultAbiCoder().encode(
    ['uint256'],
    [l2BlockNumber]
  )

  await l1.send('anvil_impersonateAccount', [proposer])
  await l1.send('anvil_setBalance', [proposer, '0xde0b6b3a7640000'])
  const data = new Interface(factoryAbi).encodeFunctionData('create', [
    1,
    rootClaim,
    extraData,
  ])
  const txHash = await l1.send('eth_sendTransaction', [
    { from: proposer, to: factoryAddr, data },
  ])
  await l1.waitForTransaction(txHash)
  await l1.send('anvil_stopImpersonatingAccount', [proposer])

  const factory = new Contract(factoryAddr, factoryAbi, l1)
  const count: bigint = await factory.gameCount()
  const [, , proxy] = await factory.gameAtIndex(count - 1n)

  await warp(l1, 1)

  return proxy
}

export async function warp(
  l1: JsonRpcProvider,
  seconds: number
): Promise<void> {
  await l1.send('evm_increaseTime', [seconds])
  await l1.send('evm_mine', [])
}

// Fast-forwards past the game clock and resolves it in favour of the proposer.
export async function resolveGame(
  l1: JsonRpcProvider,
  signer: Signer,
  gameAddr: string
): Promise<void> {
  const game = new Contract(gameAddr, gameAbi, signer)
  const maxClock: bigint = await game.maxClockDuration()
  await warp(l1, Number(maxClock) + 1)
  await (await game.resolveClaim(0, 0)).wait()
  await (await game.resolve()).wait()
}
