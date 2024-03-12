import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { arrayify } from "ethers/lib/utils";
import { ethers } from "hardhat";

async function predictContractAddress(sender: SignerWithAddress, offset: number) {
    const provider = sender.provider;
    if (!provider) {
        throw Error("No provider")
    }
    const nonce = await provider.getTransactionCount(sender.address);

    const addressBytes = ethers.utils.RLP.encode([arrayify(sender.address), arrayify(nonce + offset)]);
    const addressHash = ethers.utils.keccak256(addressBytes);
    const contractAddress = ethers.utils.getAddress("0x" + addressHash.slice(26));

    return contractAddress;
}

export {predictContractAddress}