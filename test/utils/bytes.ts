function toBuffer(input: string): Buffer {
    return Buffer.from(input.slice(2), "hex");
}

function toBytes(input: string): Uint8Array {
    return Uint8Array.from(Buffer.from(input.slice(2), "hex"));
}

function toHex(input: Buffer): `0x${string}` {
    return `0x${input.toString("hex")}`;
}

export { toBuffer, toBytes, toHex };
