import {Interface, ZeroAddress, getAddress, keccak256} from 'ethers';

export const IMPLEMENTATION_SLOT = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';
export const ADMIN_SLOT = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';
const BEACON_SLOT = '0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50';
export const same = (a, b) => typeof a === 'string' && typeof b === 'string' && a.toLowerCase() === b.toLowerCase();
const slotAddress = (value) => getAddress(`0x${value.slice(-40)}`);
const requireThat = (condition, message) => { if (!condition) throw new Error(message); };

export async function verifyRuntime(provider, identity, blockTag) {
  requireThat(identity && identity.address && identity.runtimeCodeHash, 'Missing contract identity');
  const address = getAddress(identity.address);
  const code = await provider.getCode(address, blockTag);
  requireThat(code !== '0x' && same(keccak256(code), identity.runtimeCodeHash), 'Runtime identity mismatch');
  const beacon = slotAddress(await provider.getStorage(address, BEACON_SLOT, blockTag));
  requireThat(same(beacon, ZeroAddress), 'Beacon proxies require a separate reviewed verifier');
  const implementation = slotAddress(await provider.getStorage(address, IMPLEMENTATION_SLOT, blockTag));
  if (!same(implementation, ZeroAddress)) {
    requireThat(same(implementation, identity.implementation?.address), 'Implementation address mismatch');
    const implementationCode = await provider.getCode(implementation, blockTag);
    requireThat(implementationCode !== '0x' && same(keccak256(implementationCode), identity.implementation.runtimeCodeHash), 'Implementation runtime mismatch');
  } else requireThat(!identity.implementation, 'Unexpected implementation metadata');
  const admin = slotAddress(await provider.getStorage(address, ADMIN_SLOT, blockTag));
  if (!same(admin, ZeroAddress)) requireThat(same(admin, identity.proxyAdmin), 'Proxy administrator identity required and must match');
  else requireThat(!identity.proxyAdmin, 'Unexpected proxy administrator metadata');
  return address;
}

export async function verifyDeployment(provider, entry, snapshot) {
  const address = await verifyRuntime(provider, entry, snapshot.blockNumber);
  // Accept the same evidence field names as the app's reviewed deployment registry.
  const transactionHash = entry.deploymentTransactionHash ?? entry.transactionHash;
  const blockNumber = entry.deploymentBlockNumber ?? entry.blockNumber;
  const blockHash = entry.deploymentBlockHash ?? entry.blockHash;
  requireThat(transactionHash && Number.isSafeInteger(blockNumber) && blockHash, 'Missing creation receipt evidence');
  const receipt = await provider.getTransactionReceipt(transactionHash);
  requireThat(receipt?.status === 1 && receipt.blockNumber === blockNumber && same(receipt.blockHash, blockHash)
    && blockNumber <= snapshot.finalizedBlockNumber, 'Creation receipt missing, failed, unfinalized or changed');
  const canonicalBlock = await provider.getBlock(blockNumber);
  requireThat(canonicalBlock && same(canonicalBlock.hash, blockHash), 'Creation block is not canonical');
  if (same(receipt.contractAddress, address)) return address;
  const factory = entry.factoryDeployment;
  requireThat(factory?.factory && factory.eventAbi && factory.addressArgument, 'Factory creation evidence required');
  requireThat((await provider.getCode(address, blockNumber - 1)) === '0x', 'Factory child already existed before claimed creation block');
  const createdCode = await provider.getCode(address, blockNumber);
  requireThat(createdCode !== '0x' && same(keccak256(createdCode), entry.runtimeCodeHash), 'Factory child runtime at creation mismatch');
  const factoryAddress = await verifyRuntime(provider, factory.factory, blockNumber);
  const iface = new Interface([factory.eventAbi]);
  requireThat(iface.fragments.length === 1 && iface.fragments[0].type === 'event', 'Exactly one factory creation event required');
  const matches = receipt.logs.filter((log) => same(log.address, factoryAddress)).some((log) => {
    try {
      const event = iface.parseLog(log);
      return event && same(event.args[factory.addressArgument], address);
    } catch { return false; }
  });
  requireThat(matches, 'Factory receipt does not prove the supplied child address');
  return address;
}
