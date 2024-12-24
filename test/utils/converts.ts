import { AbiCoder } from "ethers";

const abiCoder = new AbiCoder();

function hexToBuffer(hex: string): Buffer {
    if (hex.slice(0, 2) === "0x") {
        hex = hex.slice(2);
    }
    return Buffer.from(hex, "hex");
}

function bufferToBigInt(buffer: Buffer): bigint {
    // Ensure the Buffer is in Big Endian format
    let bigIntValue = BigInt(0);

    // Iterate over each byte of the buffer
    for (let i = 0; i < buffer.length; i++) {
        // Shift the current value to the left (by 8 bits for each byte)
        bigIntValue = (bigIntValue << BigInt(8)) | BigInt(buffer[i]);
    }

    return bigIntValue;
}

function numToU256(num: number): Buffer {
    return hexToBuffer(abiCoder.encode(["uint256"], [num]));
}

export { hexToBuffer, bufferToBigInt, numToU256 };
