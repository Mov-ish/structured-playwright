// check-verify-wait.js のテストフィクスチャ（pages 層）。
// ✗ = 検出されるべき違反 / ✓ = 検出されてはいけない正当形・既知の検出漏れ。
// 期待結果の正本は tests/fixtures/verify-wait/expected.txt（行番号を変えたら要更新）
export class SamplePage {
  page: any;

  // ✗ 検出対象: verify（Promise<boolean>）本体内の waitForTimeout
  async isReady(): Promise<boolean> {
    await this.page.waitForTimeout(2000);
    return true;
  }

  // ✗ 検出対象: クラスプロパティのアロー関数形の verify
  isVisible = async (): Promise<boolean> => {
    await this.page.waitForTimeout(1000);
    return true;
  };

  // ✗ 検出対象: verify 内のネストしたコールバック内の待機（broad に倒す仕様）
  async isStable(): Promise<boolean> {
    await [1].reduce(async (p) => {
      await this.page.waitForTimeout(500);
      return p;
    }, Promise.resolve(0));
    return true;
  }

  // ✓ 非検出: 操作メソッド（void）末尾の固定待機は既存慣習として許容
  async open(): Promise<void> {
    await this.page.waitForTimeout(1000);
  }

  // ✓ 非検出: verify だが waitForTimeout を含まない
  async isClosed(): Promise<boolean> {
    return this.page.isHidden();
  }

  // ✓ 非検出（既知の検出漏れ①）: 返り値注釈のないメソッドは対象外
  async isMaybe() {
    await this.page.waitForTimeout(100);
    return true;
  }
}

// ✓ 非検出（既知の検出漏れ③）: module スコープ変数形は対象外
export const isGlobalReady = async (page: any): Promise<boolean> => {
  await page.waitForTimeout(50);
  return true;
};
