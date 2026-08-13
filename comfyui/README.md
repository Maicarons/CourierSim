# 任天堂风 2D 像素游戏素材 ComfyUI 工作流

> 用于生成「透明背景 + 主体居中 + 粗黑边平涂 + 8-bit 像素风」的游戏素材。
> 已通过 http://127.0.0.1:8188/ 实际测试并迭代至最优参数。

## 交付文件

| 文件 | 用途 |
|---|---|
| `nintendo_pixel_asset_workflow.json` | **UI 格式工作流**，可直接拖入 ComfyUI 画布使用（推荐）。 |
| `graph_final.json` | **API 格式工作流**，可用脚本 `/prompt` 提交，或作为自动化/批量生成基础。 |
| `gen/nintendo_pixel_asset_00001.png` | 最终透明素材样例。 |
| `gen/nintendo_pixel_preview_00001_.png` | 去透明后的预览图样例。 |
| `gen/final_raw_preview_00001_.png` | Ernie Image Turbo 原始生成样例。 |

## 工作流管线

```
Ernie Image Turbo 文生图 (1024×1024)
  → PerfectPixel 像素网格对齐 + 最近邻缩放至 512×512
  → BiRefNet 抠图 → InvertMask 反转 → GrowMask(-1) 边缘收缩 1px
  → ImageResizeKJv2 居中留白 (pad + center)
  → ImageQuantize 16 色调色板量化
  → SaveImageWithAlpha 输出透明 PNG
```

## 关键参数说明

| 节点 | 参数 | 取值 | 原因 |
|---|---|---|---|
| EmptyFlux2LatentImage | width/height | 1024/1024 | ernie-image-turbo 原生分辨率，细节更稳。 |
| KSampler | steps/cfg | 8 / 1.0 | 该蒸馏模型官方推荐低步数 + cfg=1。 |
| KSampler | sampler/scheduler | euler / simple | 实测稳定。 |
| CLIPTextEncode | prompt | `a cute red mushroom character, 2D pixel art, Nintendo 8-bit game asset, bold black outline, flat colors, minimal shading, simple, isolated on white background` | 关键词：`Nintendo 8-bit`、`bold black outline`、`flat colors`、`minimal shading`、`isolated on white background`。 |
| ConditioningZeroOut | — | 接 negative | ernie turbo 负向直接置零，无需写负面提示词。 |
| PerfectPixel | sampling | `Center Sample` | 比 Majority Sample 更保留硬边。 |
| PerfectPixel | export_scale | 1 | 先生成原生网格，再用 ImageResizeKJv2 放大到目标尺寸，控制更准。 |
| ImageResizeKJv2 | upscale_method | `nearest-exact` | 保持硬像素边缘，无模糊。 |
| ImageResizeKJv2 | keep_proportion | `pad` | 等比缩放并居中，不拉伸变形。 |
| ImageResizeKJv2 | crop_position | `center` | 确保主体居中。 |
| GrowMask | expand | -1 | 轻微收缩遮罩，消除像素化后的边缘背景色渗漏。 |
| ImageQuantize | colors | 16 | 限制调色板，贴近 8-bit / 16-bit 主机风格。 |
| ImageQuantize | dither | `none` | 避免抖动噪点，保持大块纯色。 |
| SaveImageWithAlpha | filename_prefix | `nintendo_pixel_asset` | 透明 PNG 输出。 |

## 使用方式

1. 把 `nintendo_pixel_asset_workflow.json` 拖进 ComfyUI 浏览器窗口（确保 127.0.0.1:8188 服务已启动）。
2. 确认以下模型已存在于 `G:\ComfyUI-aki-v2\ComfyUI\models\` 对应目录：
   - `unet/ernie-image-turbo.safetensors`
   - `clip/ministral-3-3b.safetensors`
   - `vae/flux2-vae.safetensors`
   - `background_removal/birefnet.safetensors`
3. 修改 `CLIPTextEncode` 中的提示词即可生成其他道具/角色。
4. 点击「Queue Prompt」，输出结果在 `ComfyUI/output/`（或启动器配置的输出目录）。

## 迭代记录

| 版本 | 主要改动 | 结果 |
|---|---|---|
| v1 | 基础链路：文生图 → PerfectPixel → BiRefNet → SaveImageWithAlpha | 发现遮罩方向反了。 |
| v2 | 加入 InvertMask | 主体正确，但边缘有浅蓝背景渗漏。 |
| v3 | 改为先抠图再像素化（黑底合成+二次 BiRefNet） | 主体左侧被误抠，损失细节。 |
| v4 | 1024 生成 + 像素化后抠图 + GrowMask(-1) 收缩边缘 | 渗漏基本消除。 |
| v5 | Center Sample + 16 色 + 极简阴影提示词 | 最优：颜色数 10，中心偏移 < 3px，四角透明。 |
| final | 精简节点、保留预览 | 与 v5 等效，便于直接使用。 |

## 最终评估指标

- 尺寸：512 × 512 px
- 不透明像素占比：35.2%（主体饱满）
- 边界盒中心偏移：x +3.0 px，y -3.0 px（基本居中）
- 不透明区实际颜色数：10 色
- 四角 alpha：全 0（背景完全透明）

## 替换素材类型

把 `CLIPTextEncode` 的提示词换成任意游戏道具/角色即可，例如：

- `a gold coin, 2D pixel art, Nintendo 8-bit game asset, bold black outline, flat colors, minimal shading, simple, isolated on white background`
- `a green slime monster, 2D pixel art, Nintendo 8-bit game asset, bold black outline, flat colors, minimal shading, simple, isolated on white background`
- `a wooden treasure chest, 2D pixel art, Nintendo 8-bit game asset, bold black outline, flat colors, minimal shading, simple, isolated on white background`

建议保留 `Nintendo 8-bit game asset`、`bold black outline`、`flat colors`、`minimal shading`、`isolated on white background` 这些风格控制词。
