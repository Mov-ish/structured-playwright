// check-verify-wait.js のテストフィクスチャ（actions 層 — pages 限定でなく両層を走査する検証）
export class SampleAction {
  page: any;

  // ✗ 検出対象: 複数行シグネチャでも正しいメソッドに帰属する（grep/awk 近似で起きる
  //   「直前のメソッドへの誤帰属」が AST では起きないことの検証）
  async isDone(
    name: string,
  ): Promise<boolean> {
    await this.page.waitForTimeout(300);
    return name.length > 0;
  }

  // ✓ 非検出: void メソッド（複数行シグネチャ verify の直後に置き、誤帰属しないことの対照）
  async run(name: string): Promise<void> {
    await this.page.waitForTimeout(200);
    void name;
  }
}
