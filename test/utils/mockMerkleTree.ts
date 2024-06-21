import { keccak } from "hash-wasm";

function bitLength(n: number): number {
    if (n === 0) {
        return 0;
    }
    return Math.floor(Math.log(n) / Math.log(2)) + 1;
}

function genLeafData(index: number): Buffer {
    const input = Array(256).fill(0);
    input[0] = index;
    return Buffer.from(input);
}

async function genLeaf(index: number): Promise<Buffer> {
    return Buffer.from(await keccak(genLeafData(index), 256), "hex");
}

async function genLeaves(length: number): Promise<Buffer[]> {
    return await Promise.all(Array.from(new Array(length), (_, i) => genLeaf(i + 1)));
}

function pathIndex(input: string): number {
    let answer = 0;
    for (const x of input) {
        answer = 2 * answer + 1 + parseInt(x);
    }
    return answer;
}

class MockMerkle {
    leaves: Buffer[];
    tree: Buffer[];

    constructor(leaves: Buffer[]) {
        this.leaves = leaves;
        this.tree = [];
    }

    async build(): Promise<MockMerkle> {
        const length = this.leaves.length;
        const height = bitLength(length) + 1;
        const emptyLeaf = await genLeaf(0);

        // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
        const tree: Buffer[] = Array((1 << height) - 1);
        const offset = (1 << (height - 1)) - 1;
        tree[offset] = Buffer.from(Array(32).fill(0));
        for (let i = 1; i < 1 << (height - 1); i++) {
            if (i - 1 < this.leaves.length) {
                tree[offset + i] = this.leaves[i - 1];
            } else {
                tree[offset + i] = emptyLeaf;
            }
        }

        for (let h = height - 1; h > 0; h--) {
            const offset = (1 << (h - 1)) - 1;

            for (let i = 0; i < 1 << (h - 1); i++) {
                const left: number = 2 * (offset + i) + 1;
                const right: number = 2 * (offset + i) + 2;
                tree[offset + i] = Buffer.from(await keccak(Buffer.concat([tree[left], tree[right]]), 256), "hex");
            }
        }

        this.tree = tree;
        return this;
    }

    at(input: string): Buffer {
        return this.tree[pathIndex(input)];
    }

    root(): Buffer {
        return this.at("");
    }

    height(): number {
        return Math.round(Math.log(this.tree.length + 1) / Math.log(2));
    }

    slice(start: number, end: number): readonly Buffer[] {
        const offset = (1 << this.height()) / 2 - 1;
        return this.tree.slice(start + offset, end + offset);
    }

    length(): number {
        return this.leaves.length + 1;
    }

    proof(index: number): Buffer[] {
        const height = this.height() - 1;
        let indexString = "";
        for (let i = 0; i < height; i++) {
            if (index % 2 === 0) {
                indexString = "0" + indexString;
            } else {
                indexString = "1" + indexString;
            }
            index = Math.floor(index / 2);
        }

        const sibling = function (path: string) {
            if (path[path.length - 1] === "0") {
                return path.slice(0, path.length - 1) + "1";
            } else {
                return path.slice(0, path.length - 1) + "0";
            }
        };

        const proof: Buffer[] = [];

        for (let i = height; i > 0; i--) {
            proof.push(this.at(sibling(indexString.slice(0, i))));
        }

        return proof;
    }

    getUnsealedData(recallPosition: number): Buffer[] {
        const unsealedData: Buffer[] = [];
        for (let i = 0; i < 16; i++) {
            const leafData = genLeafData(recallPosition + i);
            for (let j = 0; j < 256; j += 32) {
                unsealedData.push(leafData.subarray(j, j + 32));
            }
        }
        return unsealedData;
    }
}

export { MockMerkle, genLeaf, genLeaves, genLeafData };
