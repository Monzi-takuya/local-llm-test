# フェーズ 11: 東京 L4 に 27B 全載せ（IAP・外部 IP なし）

日付: 2026-09-15。project `monzi-sandbox`。GPU VM は記録時点で未作成 → 以降に create。

## 読み取り（GPU 課金なし）

```bash
gcloud config get-value project
# monzi-sandbox（Owner。メールは git に書かない）
```

| 項目 | 実測 |
| --- | --- |
| `GPUS_ALL_REGIONS` | limit **1** / usage **0** |
| 東京 `NVIDIA_L4_GPUS` | limit **1** / usage **0** |
| `PREEMPTIBLE_CPUS` | 0（Spot 不可） |
| GCE VM | なし |
| IAP API | **ENABLED**（追加 enable なし） |
| 既存 NAT router（東京） | なし |
| SSH fw | `default-allow-ssh` が `0.0.0.0/0`（読み取り時）。**IAP 専用に差し替え予定**（Cloud Run 非依存） |
| DLVM イメージ | `common-cu129-ubuntu-2204-nvidia-580-v20260909` READY |
| 実効 `vmExternalIpAccess` | **denyAll**（`--no-address` 必須） |
| 実効 `restrictCloudNATUsage` | **allowAll** |

プロジェクト直下の org policy は `POLICY_NOT_FOUND`。`--effective` で org `171053930055` からの継承を見た。

## IAP fw と NAT（人が作成、2026-09-15）

`allow-ssh-from-iap`: ingress tcp:22、source `35.235.240.0/20`、target tag `allow-iap-ssh`。
`default-allow-ssh` と `default-allow-rdp` は削除済み（NOT_FOUND）。`default-allow-internal` は残している想定。

東京 Cloud NAT: router `nat-router-tokyo`、nat `nat-config`。`ALL_SUBNETWORKS_ALL_IP_RANGES`、NAT IP は AUTO。EIP deny のまま。

## create（2026-09-15 01:59 JST）

`scripts/gcp/create.sh`。`g2-standard-8` は機種に L4 が付くので `--accelerator` は付けない。

| ゾーン | 結果 |
| --- | --- |
| asia-northeast1-a | `ZONE_RESOURCE_POOL_EXHAUSTED` |
| asia-northeast1-b | 同上 |
| asia-northeast1-c | **RUNNING** `l4-27b`、内部 IP `10.146.0.3`、**EXTERNAL_IP なし** |

`networkInterfaces[].accessConfigs` は無し。tag `allow-iap-ssh`。`onHostMaintenance: TERMINATE`。

IAP SSH で `nvidia-smi`: NVIDIA L4、**23034 MiB**、Driver 580.178.04、CUDA 13.0。

## モデル配置

公式 Linux CUDA zip は GitHub Releases に無い（Windows CUDA のみ）。DLVM 上で `ggml-org/llama.cpp` を `GGML_CUDA=ON` でソースビルドした（commit `41abbfd`、`llama-cli` 0.4.1-dev）。全 SM 向けのため約 1 時間。次回は `-DGGML_CUDA_ARCHITECTURES=89` で短縮できる。

GGUF は NAT 経由 `hf download`（トークンなし）。

```bash
hf download unsloth/Qwen3.8-27B-GGUF Qwen3.8-27B-UD-Q4_K_M.gguf --local-dir ~/models
# 約 16G。未認証でも数分で完了
```

IAP scp は使っていない。

## ベンチ（ja、フェーズ 7 と同じ greedy）

プロンプト: [`05-prompt-ja.txt`](05-prompt-ja.txt)。`-ngl 99 -c 2048 -n 128 --temp 0 --reasoning off`。

生ログ: [`11-raw/bench-ja.txt`](11-raw/bench-ja.txt)。

| 項目 | L4 全載せ（今回） | ローカル 5060 部分 GPU（フェーズ 7） |
| --- | --- | --- |
| 機種 | 東京 `g2-standard-8` / L4 24GB | RTX 5060 8GB、`-ngl 30 -t 12` |
| Prompt | **83.9 tok/s** | 約 21 |
| Generation | **14.5 tok/s** | **3.7 tok/s** |
| VRAM max | **15320 MiB** / 23034 | 7714 MiB / 8192 |
| 対話目安 8 tok/s | **達した** | 未達 |
| 紙上 decode | 帯域から約 15 | — |

生成文:

> WindowsのGUI環境を維持したまま、Linuxネイティブのツールチェーンや高性能な推論ライブラリをシームレスに利用して開発効率を最大化するため。

紙上 15 に対して実測 14.5。帯域律速の概算は当たっていた。ローカル 3.7 の約 **3.9 倍**。

## stop

create 01:59 JST → stop **03:11 JST**（`TERMINATED`）。約 **72 分 RUNNING**。`$1.0962/h` × 1.2h ≈ **$1.32**。NAT 16G 約 $0.72。GPU+NAT は **$10 枠内**。ディスクと GGUF は残した（delete していない）。

```bash
scripts/gcp/stop.sh
# status: TERMINATED
```

やらなかったこと: pcd-study LB への載せる、Iowa、IAP scp、delete、Cloud Run の変更。


