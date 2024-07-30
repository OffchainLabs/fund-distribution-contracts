import { JsonRpcProvider, Wallet } from 'ethers'
import { ethers as ethersv5 } from 'ethers-v5'

export type Unwrap<T> = T extends Promise<infer U> ? U : T

export function getEnv(name: string): string {
  const value = process.env[name] || ''
  if (value === '') {
    throw new Error(`Environment variable ${name} is not defined`)
  }
  return value
}

/**
 * Produces a v6 provider from a v5 provider
 * @param provider An ethers v5 JsonRpcProvider
 * @returns An ethers v6 JsonRpcProvider
 */
export function toV6Provider(provider: ethersv5.providers.JsonRpcProvider) {
  const url = provider.connection.url
  if (!url) {
    throw new Error('Provider does not have a connection url')
  }
  return new JsonRpcProvider(provider.connection.url)
}

/**
 * Produces a v6 wallet from a v5 wallet
 * @param wallet An ethers v5 Wallet
 * @throws If the wallet provider is not a JsonRpcProvider
 * @returns An ethers v6 Wallet
 */
export function toV6Wallet(
  wallet: ethersv5.Wallet
): Wallet & { provider: JsonRpcProvider } {
  if (!(wallet.provider instanceof ethersv5.providers.JsonRpcProvider)) {
    throw new Error('Wallet provider is not a JsonRpcProvider')
  }
  return new Wallet(
    wallet.privateKey,
    toV6Provider(wallet.provider)
  ) as Wallet & { provider: JsonRpcProvider }
}
