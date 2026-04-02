# Cent Jours — AI 生成美术提示词模板库
**对应 docs/plans/product_plan.md §3.7.6 + §3.7.7**

---

## 1. 人物肖像提示词模板

### 1.1 基础模板（所有人物通用）

```
[CHARACTER_DESCRIPTION], neoclassical portrait, oil painting style,
dark moody background (#1A1A2E to #2A1808 gradient),
dramatic chiaroscuro lighting from upper left,
Napoleonic era [UNIFORM_TYPE],
Jacques-Louis David influence, Jean-Auguste-Dominique Ingres influence,
museum quality digital painting, warm golden undertones,
detailed fabric texture with gold trim, bust portrait,
three-quarter view facing right, intense gaze,
rich deep shadows, painterly brushwork,
--ar 1:1 --style raw --v 6
```

**负向提示词**:
```
anime, cartoon, flat colors, photorealistic, 3d render,
modern clothing, bright backgrounds, white background,
low quality, blurry, watermark, signature
```

---

### 1.2 各人物专用提示词

#### 拿破仑 · 波拿巴
```
Napoleon Bonaparte, 46 years old, Mediterranean features, receding hairline,
intense piercing grey eyes, slight overweight but commanding presence,
wearing imperial French military uniform dark blue with gold epaulettes,
Légion d'honneur on chest, Emperor's laurel crown nearby (not worn),
neoclassical portrait, oil painting style,
dark moody background, dramatic chiaroscuro lighting from upper left,
Jacques-Louis David influence,
museum quality digital painting, warm golden undertones,
three-quarter view, bust portrait, --ar 1:1 --style raw
```

#### Michel Ney（内伊）
```
Michel Ney, French Marshal, 46 years old, red hair (auburn),
strong jaw, blue eyes, weathered soldier's face, determined expression,
wearing Marshal of France dark blue uniform with gold trim,
sword pommel visible at shoulder,
neoclassical portrait, oil painting style,
dark dramatic background, chiaroscuro lighting,
Jacques-Louis David influence, museum quality,
--ar 1:1 --style raw
```

#### Louis-Nicolas Davout（达武）
```
Louis-Nicolas Davout, French Marshal, 45 years old,
bald or very short hair, round face, calm intelligent eyes,
wearing Marshal of France uniform, severe yet composed expression,
suggestion of absolute reliability in posture,
neoclassical portrait, oil painting style,
dark background, dramatic side lighting,
--ar 1:1 --style raw
```

#### Emmanuel de Grouchy（格鲁希）
```
Emmanuel de Grouchy, French Marshal, 48 years old,
aristocratic features, slightly receding dark hair,
cautious hesitant expression, formal military bearing,
wearing Marshal of France uniform,
neoclassical portrait, oil painting style,
dark background, subdued lighting suggesting uncertainty,
--ar 1:1 --style raw
```

#### Joseph Fouché（福歇）
```
Joseph Fouché, French politician, 55 years old,
thin pale face, cold calculating eyes, thin lips slightly smiling,
wearing formal civilian dark coat with minimal decoration,
expression of someone who knows secrets, slightly sinister,
neoclassical portrait, oil painting style,
very dark background, candlelight effect,
--ar 1:1 --style raw
```

#### Lazare Carnot（卡尔诺）
```
Lazare Carnot, French statesman, 62 years old,
round honest face, grey hair, idealistic yet tired eyes,
wearing republican-era formal coat, modest decorations,
expression of principled determination,
neoclassical portrait, oil painting style,
dark neutral background, even lighting,
--ar 1:1 --style raw
```

#### 司汤达（Stendhal / Marie-Henri Beyle）

> TODO(history): 若游戏内日记叙事者切换为 `Henri Gatien Bertrand`，这里的人物模板也要同步替换；Stendhal 保留为文学参考来源，不再默认作为百日在场 NPC。

```
Stendhal, Marie-Henri Beyle, French writer, 32 years old,
chubby round face, intelligent ironic eyes, hint of smile,
wearing Napoleonic era civilian coat, quill pen suggested nearby,
observer's expression, slightly detached amusement,
neoclassical portrait, oil painting style,
dark background with soft warm candlelight,
--ar 1:1 --style raw
```

---

### 1.3 统一后期处理步骤

生成后对所有肖像执行：

1. **色温统一**: Lightroom/Photoshop 色温调至 6000-6400K（暖金调）
2. **背景统一**: 替换为 `radial-gradient(#2A1808 center, #0E0A06 edges)`
3. **光源方向**: 检查并统一为左上 45° 主光（如不一致，用 Frequency Separation + 液化调整）
4. **圆形裁切**: 以面部为中心裁切正圆，保留肩部少量
5. **双层金色描边**:
   - 外层: `3px solid #C9A84C`，外发光 `0 0 8px rgba(201,168,76,0.5)`
   - 内层: `1px solid #8B7332`
6. **整体色调叠加**: 添加 `rgba(201,168,76,0.05)` 暖金色叠加层
7. **导出**: PNG-32，512×512px（游戏用）+ 1024×1024px（Steam商店用）

---

## 2. 地图底图提示词模板

### 2.1 主地图底图（法国 + 比利时）

**Midjourney v6**:
```
Detailed topographic map of France and Belgium, 1815 era style,
dark navy blue (#0A1020) ocean and water bodies,
deep forest green and dark earth tones (#1C2410) land masses,
subtle terrain elevation shading with gentle highlights on hills,
rivers as thin silver lines with soft glow,
Mediterranean coastline clearly defined,
Pyrénées and Alps visible as darker elevated terrain,
English Channel and Atlantic Ocean as deep blue-black,
no text, no labels, no borders, no roads visible,
painterly antique cartography aesthetic,
birds eye view orthographic projection,
4K ultra detailed, --ar 4:3 --style raw --v 6
```

**Stable Diffusion (SDXL)**:
```
提示词: (topographic map:1.3), France Belgium, dark navy background,
(dark green land:1.2), (silver rivers:1.1), terrain elevation shading,
mediterranean coastline, no text, no labels, aerial view,
painterly style, antique map aesthetic, dark moody colors,
(deep shadows mountains:1.2)

Negative: text, labels, borders, roads, bright colors,
white background, cartoon, modern style
```

### 2.2 クローズアップ：比利时战场（Day 85-100用）

```
Detailed topographic map close-up of Belgium and northern France,
Waterloo region, 1815, dark color palette,
rolling hills and ridgelines visible,
Sombre and Meuse rivers,
dense forest areas as dark patches,
no text no labels, painterly style,
dramatic stormy atmosphere, dark overcast sky implied,
--ar 16:9 --style raw
```

---

## 3. 决策卡片缩略图提示词模板

每种政策类型各1张，64×64px 后缩放，深色调与卡片背景融合。

```
[SCENE_DESCRIPTION], Napoleonic era illustration,
dark moody color palette, painterly style,
warm candlelight or torchlight,
small square thumbnail composition,
no text, high contrast, impressionistic,
--ar 1:1 --style raw
```

| 政策类型 | SCENE_DESCRIPTION |
|---------|-------------------|
| 征兵令 | Young French soldiers marching in formation, torchlight |
| 颁布宪法 | Quill pen signing document, candlelight on parchment |
| 公开演说 | Crowd gathered in Paris square, speaker on podium |
| 增加军费 | Cannon and weapons in imperial armory, dramatic lighting |
| 减税 | Market scene Paris, bread and goods, humble people |
| 授予头衔 | Napoleon presenting medal, formal ceremony, gold light |
| 秘密外交 | Two figures whispering in shadow, candlelit room |
| 印钞 | Printing press in dark workshop, stacks of paper money |

---

## 4. 主菜单背景

```
Epic neoclassical painting style, Napoleon Bonaparte on horseback,
surveying a vast French landscape at golden hour,
dramatic sky with storm clouds breaking,
French imperial eagle banner in background,
Jacques-Louis David painting style,
dark moody atmosphere, golden hour light rays,
museum quality digital painting, cinematic composition,
--ar 16:9 --style raw --v 6
```

---

## 5. AI 生成工作流建议

```
流程图:

生成 (SD/MJ)
    ↓
初筛 (20%-30%留用)
    ↓
Lightroom 批量调色
    ↓
Photoshop 精修 (面部/手部/细节)
    ↓
统一后期 (见1.3)
    ↓
质量审核 (风格一致性/历史准确性)
    ↓
导出 (512px游戏版 + 1024px宣传版)
```

**预计工作量**:
- 肖像: 20张 × 平均3次迭代 = 60次生成 + 10-15小时后期
- 地图: 5-8次迭代 = 2-3小时后期
- 决策缩图: 8张 × 2次迭代 = 16次生成 + 2小时后期
- **总计**: 约80次生成 + 15-20小时后期处理
