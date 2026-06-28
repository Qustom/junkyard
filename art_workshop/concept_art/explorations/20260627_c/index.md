# Exploration Batch — 2026-06-27 (c) · "One prompt, every model" sweep

> **Not direction.** Exploratory AI probes — see [`../README.md`](../README.md). These do not define the game's art direction.

## What this batch probed

A single **fixed prompt** — the **16-bit pixel-art** rendering of the Bellweather Salvage office + surface junkyard (the winning style from batch [`../20260627_b/`](../20260627_b/)) — run through **every runnable text-to-image model on fal.ai**, to compare how each model interprets the *same* brief. The exact prompt is in [`PROMPT.txt`](PROMPT.txt) (also embedded below).

**118 models returned an image.** ~7 endpoints failed or didn't finish (listed at the bottom).

### The prompt (identical for every model)

```
A sprawling, cluttered American junkyard at golden hour — towering piles of rusted cars,
scrap metal, broken appliances, old machinery, tangled wire. In the foreground a small,
lived-in salvage-yard office shed with a warm glowing window and a faded hand-painted
'BELLWEATHER SALVAGE' sign. Long golden shadows, dust motes in warm light, nostalgic
melancholy mood. Deep among the distant scrap, a faint uncanny cold-violet glow hints at
something that doesn't belong. Wide establishing view of the yard and its office.
ART STYLE: rendered as detailed 16-bit pixel art, retro SNES-era game art, crisp visible
pixels, dithering, limited cohesive palette, top-down-leaning adventure-game aesthetic.
No game title, no title card, no logo, no watermark, no UI, no extra lettering except the
painted sign.
```

## Method & deviations from the template

- **Prompt-only input.** To run one call across ~120 heterogeneous schemas, only `prompt` was passed; models used their own default size/aspect (hence square, 16:9, 4:3, and 4K outputs all appear).
- **Consolidated record (template deviation).** Per the per-image-`_GENERATION.md` rule this batch would need 118 near-identical records (same prompt, same date). Instead this single `index.md` is the authoritative record; the per-image detail that differs (model, endpoint, file, format) is the table below. Flagged here as the intentional deviation.
- **Not individually graded.** With 118 outputs, images were **not** each visually reviewed/scored. Treat the table as an inventory for eyeballing, not a ranked verdict. The on-style reference winner remains **Nano Banana Pro** (`nanobanana_pro.png`) from prior batches.
- **Prompt rewriting.** Some models (Ideogram v4, Wan, Ernie, Seedream, the Bria/Fibo family) auto-expand or restructure the prompt into JSON/long-form before rendering — noted where seen; output still reflects the same brief.

## Inventory — 118 images by model family

### FLUX family (Black Forest Labs)
| File | Endpoint |
|---|---|
| `flux_schnell.jpg` | fal-ai/flux/schnell |
| `flux_dev.jpg` | fal-ai/flux/dev |
| `flux_krea.jpg` | fal-ai/flux/krea |
| `flux_srpo.jpg` | fal-ai/flux/srpo |
| `flux_pro_v11.jpg` | fal-ai/flux-pro/v1.1 |
| `flux_pro_v11_ultra.jpg` | fal-ai/flux-pro/v1.1-ultra |
| `flux_kontext_pro.jpg` | fal-ai/flux-pro/kontext/text-to-image |
| `flux_kontext_max.jpg` | fal-ai/flux-pro/kontext/max/text-to-image |
| `flux2_dev.png` | fal-ai/flux-2 |
| `flux2_pro.jpg` | fal-ai/flux-2-pro |
| `flux2_max.jpg` | fal-ai/flux-2-max |
| `flux2_flex.jpg` | fal-ai/flux-2-flex |
| `flux2_turbo.png` | fal-ai/flux-2/turbo |
| `flux2_flash.png` | fal-ai/flux-2/flash |
| `flux2_klein9b.png` | fal-ai/flux-2/klein/9b |
| `flux2_klein9b_base.png` | fal-ai/flux-2/klein/9b/base |
| `flux2_klein4b.png` | fal-ai/flux-2/klein/4b |
| `flux2_klein4b_base.png` | fal-ai/flux-2/klein/4b/base |

### Google Nano Banana / Gemini
| File | Endpoint |
|---|---|
| `nanobanana.png` | fal-ai/nano-banana |
| `nanobanana2.png` | fal-ai/nano-banana-2 |
| `nanobanana_pro.png` | fal-ai/nano-banana-pro **(on-style reference winner)** |

### OpenAI GPT-Image
| File | Endpoint |
|---|---|
| `gpt_image_2.png` | openai/gpt-image-2 |
| `gpt_image_15.png` | fal-ai/gpt-image-1.5 |
| `gpt_image_1.png` | fal-ai/gpt-image-1/text-to-image |
| `gpt_image_1_mini.png` | fal-ai/gpt-image-1-mini |

### ByteDance Seedream / Dreamina
| File | Endpoint |
|---|---|
| `seedream_v4.png` | fal-ai/bytedance/seedream/v4/text-to-image |
| `seedream_v45.png` | fal-ai/bytedance/seedream/v4.5/text-to-image |
| `seedream_v5_lite.png` | fal-ai/bytedance/seedream/v5/lite/text-to-image |
| `dreamina_v31.png` | fal-ai/bytedance/dreamina/v3.1/text-to-image |

### Qwen
| File | Endpoint |
|---|---|
| `qwen_image.png` | fal-ai/qwen-image |
| `qwen_image_2512.png` | fal-ai/qwen-image-2512 |
| `qwen_image_2.png` | fal-ai/qwen-image-2/text-to-image |
| `qwen_image_2_pro.png` | fal-ai/qwen-image-2/pro/text-to-image |

### Recraft
| File | Endpoint |
|---|---|
| `recraft_v3.webp` | fal-ai/recraft/v3/text-to-image |
| `recraft_v4.webp` | fal-ai/recraft/v4/text-to-image |
| `recraft_v4_pro.webp` | fal-ai/recraft/v4/pro/text-to-image |
| `recraft_v41.webp` | fal-ai/recraft/v4.1/text-to-image |
| `recraft_v41_pro.webp` | fal-ai/recraft/v4.1/pro/text-to-image |
| `recraft_20b.webp` | fal-ai/recraft-20b |

### Ideogram
| File | Endpoint |
|---|---|
| `ideogram_v2.png` | fal-ai/ideogram/v2 |
| `ideogram_v2_turbo.png` | fal-ai/ideogram/v2/turbo |
| `ideogram_v2a.png` | fal-ai/ideogram/v2a |
| `ideogram_v2a_turbo.png` | fal-ai/ideogram/v2a/turbo |
| `ideogram_v3.png` | fal-ai/ideogram/v3 |
| `ideogram_v4.jpg` | ideogram/v4 *(expanded prompt to JSON)* |

### Krea
| File | Endpoint |
|---|---|
| `krea2_large.png` | krea/v2/large/text-to-image |
| `krea2_medium.png` | krea/v2/medium/text-to-image |
| `krea2_medium_turbo.png` | krea/v2/medium/turbo/text-to-image |
| `krea2_turbo.png` | fal-ai/krea-2/turbo |

### Z-Image (Tongyi-MAI)
| File | Endpoint |
|---|---|
| `zimage_turbo.png` | fal-ai/z-image/turbo |
| `zimage_base.png` | fal-ai/z-image/base |

### Sana (NVIDIA)
| File | Endpoint |
|---|---|
| `sana.jpg` | fal-ai/sana *(4K output)* |
| `sana_sprint.jpg` | fal-ai/sana/sprint *(4K)* |
| `sana_v15_48b.jpg` | fal-ai/sana/v1.5/4.8b *(4K)* |
| `sana_v15_16b.jpg` | fal-ai/sana/v1.5/1.6b *(4K)* |

### Stable Diffusion / SDXL & relatives
| File | Endpoint |
|---|---|
| `sdxl_fast.jpg` | fal-ai/fast-sdxl |
| `sdxl_lightning.jpg` | fal-ai/fast-lightning-sdxl |
| `sd35_large.jpg` | fal-ai/stable-diffusion-v35-large |
| `sd35_medium.jpg` | fal-ai/stable-diffusion-v35-medium |
| `sd3_medium.png` | fal-ai/stable-diffusion-v3-medium |
| `sd15.jpg` | fal-ai/stable-diffusion-v15 *(512×512)* |
| `lcm_diffusion.jpg` | fal-ai/fast-lcm-diffusion *(returned inline base64; decoded locally)* |
| `stable_cascade.jpg` | fal-ai/stable-cascade |
| `sote_diffusion.jpg` | fal-ai/stable-cascade/sote-diffusion *(anime finetune)* |
| `playground_v25.jpg` | fal-ai/playground-v25 |

### Hunyuan (Tencent)
| File | Endpoint |
|---|---|
| `hunyuan_v3.png` | fal-ai/hunyuan-image/v3/text-to-image |
| `hunyuan_v3_instruct.png` | fal-ai/hunyuan-image/v3/instruct/text-to-image *(ultrawide 1472×576)* |
| `hunyuan_v21.png` | fal-ai/hunyuan-image/v2.1/text-to-image |

### HiDream
| File | Endpoint |
|---|---|
| `hidream_i1_fast.jpg` | fal-ai/hidream-i1-fast |
| `hidream_i1_full.jpg` | fal-ai/hidream-i1-full |
| `hidream_i1_dev.jpg` | fal-ai/hidream-i1-dev |
| `hidream_o1_dev.png` | fal-ai/hidream-o1-image/dev |

### Luma
| File | Endpoint |
|---|---|
| `luma_photon.jpg` | fal-ai/luma-photon |
| `luma_photon_flash.jpg` | fal-ai/luma-photon/flash |
| `luma_uni1.png` | luma/agent/uni-1/v1/text-to-image |
| `luma_uni1_max.png` | luma/agent/uni-1/v1/max |

### Wan (Alibaba)
| File | Endpoint |
|---|---|
| `wan_v27.jpg` | fal-ai/wan/v2.7/text-to-image |
| `wan_v27_pro.jpg` | fal-ai/wan/v2.7/pro/text-to-image |
| `wan_v26.png` | wan/v2.6/text-to-image *(also returned a prose caption)* |
| `wan_v25.png` | fal-ai/wan-25-preview/text-to-image *(rewrote prompt)* |
| `wan_v22_a14b.jpg` | fal-ai/wan/v2.2-a14b/text-to-image |
| `wan_v22_5b.jpeg` | fal-ai/wan/v2.2-5b/text-to-image |

### Bria / Fibo (licensed-data models)
| File | Endpoint |
|---|---|
| `bria_base.png` | fal-ai/bria/text-to-image/base |
| `bria_fast.png` | fal-ai/bria/text-to-image/fast |
| `fibo.png` | bria/fibo/generate *(JSON structured prompt)* |
| `fibo_lite.png` | bria/fibo-lite/generate *(JSON structured prompt)* |
| `fibo_bbq.png` | bria/fibo-bbq-preview/generate *(JSON structured prompt)* |

### Baidu Ernie
| File | Endpoint |
|---|---|
| `ernie.jpg` | fal-ai/ernie-image *(rewrote prompt)* |
| `ernie_turbo.jpg` | fal-ai/ernie-image/turbo *(rewrote prompt)* |

### ImagineArt
| File | Endpoint |
|---|---|
| `imagineart_20.png` | imagineart/imagineart-2.0-preview/text-to-image |
| `imagineart_15_pro.webp` | imagineart/imagineart-1.5-pro-preview/text-to-image |

### Juggernaut (RunDiffusion / Flux finetunes)
| File | Endpoint |
|---|---|
| `juggernaut_base.png` | rundiffusion-fal/juggernaut-flux/base |
| `juggernaut_lightning.png` | rundiffusion-fal/juggernaut-flux/lightning |
| `juggernaut_pro.png` | rundiffusion-fal/juggernaut-flux/pro |

### Kling (Kuaishou)
| File | Endpoint |
|---|---|
| `kling_v3.png` | fal-ai/kling-image/v3/text-to-image |
| `kling_o3.png` | fal-ai/kling-image/o3/text-to-image |

### xAI Grok
| File | Endpoint |
|---|---|
| `grok_imagine.jpg` | xai/grok-imagine-image |
| `grok_imagine_quality.jpg` | xai/grok-imagine-image/quality/text-to-image |

### Other distinct models
| File | Endpoint |
|---|---|
| `mai_image_25.png` | microsoft/mai-image-2.5 |
| `minimax_image01.jpg` | fal-ai/minimax/image-01 |
| `kolors.png` | fal-ai/kolors |
| `auraflow.png` | fal-ai/aura-flow |
| `lumina_v2.jpg` | fal-ai/lumina-image/v2 |
| `cogview4.jpg` | fal-ai/cogview4 |
| `pixart_sigma.jpg` | fal-ai/pixart-sigma |
| `dreamshaper.jpg` | fal-ai/dreamshaper |
| `pony_v7.jpg` | fal-ai/pony-v7 |
| `fooocus.jpg` | fal-ai/fooocus |
| `janus.png` | fal-ai/janus *(DeepSeek; small 384×384)* |
| `bagel.jpg` | fal-ai/bagel *(ByteDance-Seed)* |
| `longcat.png` | fal-ai/longcat-image |
| `glm_image.jpg` | fal-ai/glm-image |
| `ovis_image.png` | fal-ai/ovis-image |
| `nucleus_image.png` | fal-ai/nucleus-image |
| `bitdance.jpg` | fal-ai/bitdance |
| `emu_35.png` | fal-ai/emu-3.5-image/text-to-image |
| `cosmos3_super.jpg` | nvidia/cosmos-3-super/text-to-image |
| `vidu_q2.png` | fal-ai/vidu/q2/text-to-image |

## Did not complete (excluded from the 118)

| Endpoint | Reason |
|---|---|
| fal-ai/hyper-sdxl | 404 — application not found (dead endpoint) |
| bria/text-to-image/3.2 | 403 — account cannot access this app |
| fal-ai/bria/text-to-image/hd | 500 — downstream service error |
| fal-ai/hidream-o1-image | stuck IN_PROGRESS, no result after ~40 min |
| fal-ai/realistic-vision | stuck IN_PROGRESS, no result after ~40 min |
| fal-ai/qwen-image-max/text-to-image | result fetch returned 504 persistently (~40 min) |
| imagineart/imagineart-1.5-preview (non-pro) | not run (1.5-pro covered the family) |

Excluded by design (not "runnable from a bare prompt"): alias duplicates (`flux-1/*`, `gemini-*`=Nano Banana), all LoRA-required endpoints, ControlNet/inpainting/img2img/subject endpoints, vector/SVG (Recraft vector, VecGlypher), PBR material (PATINA), edge-detection, upscalers, and the FLUX-2 LoRA-gallery style filters.

## Cost

~118 paid generations across mixed pricing (flat per-image $0.04–0.15 for the premium models; per-megapixel $0.01–0.04 for FLUX/SD/Sana — Sana's 4K outputs cost more per call). **Rough batch total ≈ $4–6.** Exact figure depends on fal's per-megapixel billing for the variable-size outputs; check the fal.ai dashboard for the authoritative charge.

## Takeaway

This is a model *coverage* sweep, not a curated pick. For the project's locked top-down **pixel-art** direction, the earlier-identified **Nano Banana Pro** (`nanobanana_pro.png`) remains the cleanest interpreter of this exact prompt; **Seedream**, **Recraft**, **Ideogram v3/v4**, **Qwen-Image-2**, and **Z-Image** are worth a closer look as alternates. Picking among them is a Director call — nothing here sets direction.
