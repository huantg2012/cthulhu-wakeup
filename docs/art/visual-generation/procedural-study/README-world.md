# 原作星球生成桥

运行：`python3 server.py`，打开 `http://127.0.0.1:8950/`。需要本机 Godot；默认读取 `/Applications/Godot.app/Contents/MacOS/Godot`，也可使用 `GODOT_BIN` 或 `--godot`。

## 接口

- `GET /api/config`：`templates` / `palettes` / `styles` 数组及 `defaults`。两个原有世界名称来自正式 `data/player_text.csv`，其余为原型名候选；教团/人物是 `templates.csv` 的明确视觉候选，不表示已存在于存档。
- `POST /api/world`，`Content-Type: application/json`，四字段：`{"template":"tide","seed":1337,"style":0,"palette":7}`。`style` 是原作 shader sid，接受 `0/1/2/4/6/7`，分别映射原作表索引 `0/1/2/3/4/5`；`palette` 接受 `0..9`，`seed` 接受 `0..999999`。
- 返回 `url`（同源 `/cache/<hash>.png`）、`params`、`hash`、`sourceFingerprint`、`identity`、`styleSid`、`time`、`framesAfterRebuild`、`size`、`cached` 和原请求。
- `POST /api/style`：`{"request":{"template":"tide","seed":1337,"style":0,"palette":7},"images":{"cult":"data:image/png;base64,...","person":"data:image/png;base64,..."},"normals":{"cult":"data:image/png;base64,...","person":"data:image/png;base64,..."}}`。每张PNG最多5MB、边长最多4096；返回 `urls`、`hashes`、`inputHashes`、`params`、`sourceFingerprint`、`adapterFingerprint`、`postShaderHash`、`identity`、`styleSid`、`time`、`framesAfterRebuild`、`size`、`cached` 和 `method`。

服务仅绑定127.0.0.1，拒绝非本机Host及跨来源POST，不开放CORS。静态页与API共用端口，无外部账号或图像API。

## 真正生成与可复现范围

服务从只读 `godot-base/` 计算源码/资源指纹，复制到独立临时目录并在那里导入。新参数调用原 `main.gd → generator.gd → post.gdshader → shots.gd`，正常图形渲染输出PNG；不以headless dummy渲染替代。渲染请求串行，避免多个Godot同时争用GPU。相同来源指纹、模板和全部参数才复用缓存；缓存PNG另核自身SHA256。`cache/` 自带忽略规则，只保留 `.gitignore`。

固定参数：星球场景、居中、1:1标准960×960、g_time=3、停止动画、rebuild后4帧、腐化0.2、扭曲0.06、星云0.25、count0、rings2；触手/眼/符文0，全部标题/标签/框/色卡关闭。返回JSON公开全部参数。模板、seed、style、palette均进入原生成器实际参数；不存在固定图换名。

十份调色板是原EData c0..c4的精确映射，加载时核对原作，防止教团人物与世界色表悄悄分叉。`paper/ink` 来自原作常量。

## 二维画稿复用原作表面与后期

`style_2d.gd` 在临时工程继承原 `main.gd`，保留该世界生成的原天空节点，移除星球等对象；不新增人物或建筑三维模型。浏览器发送两张二维颜色图和两张由形体遮罩距离产生的二维法线/材质图，`surface_2d.gdshader` 直接 include 原工程 `common.gdshaderinc`，调用原始 `fbm3`、`ridged3`、`voronoi3`、`style_shade` 与 `rim_term`，使用同参数世界重建出的原 `g_light_dir`、环境光、光色与原调色板。石材的颜色/高度关系参考 `s_drowned`，并在部分原型上加入各自的简化噪声与地形特征，以二维UV及种子重写采样域；布料不使用石材裂缝。然后经过原样 `bloom_down → bloom_blur → post.gdshader`。

这复用了具体函数与世界光照，**不是**原球面几何、原球面法线或完整 `s_drowned`，不代表造型/美术自动一致。原天空节点来自原工程既有场景（其底层是天空球），不是为教团或人物新建三维模型。

两图共用一次Godot进程，并与星球请求共用渲染锁。缓存键包括四张输入PNG的SHA256、原作全部来源指纹、二维适配脚本与表面shader指纹及完整参数。响应包括 `lighting`（含原天空数量）、`surfaceShaderFingerprint` 及原后期hash。任何输入、适配器、shader或原作源码改变都会重新渲染。

## 历史后期验证与当前校验

`tide / seed1337 / style0 / palette7` 已通过API运行原作生成，PNG与上一轮独立基准 `card-study/reference-check/reference-world.png` **字节完全一致**，SHA256：
`332e8c43f4a7e25fb67f5c1be00687b96fd382f9750ec3afdd42435945781c3d`。

重复同一请求实测 `cached:true`、同hash。Python语法检查通过；正常渲染结果已看图，原 `godot-base` 无修改。本桥不改变正式游戏、存档或Session，不对教团与人物的画法质量作结论。

旧版仅共用后期时，同一请求下两张768×768二维画稿经 `/api/style` 实际运行，均返回960×960 PNG；已查看输出，教团建筑与持仪器兜帽人物内容保留，暗边、颗粒与高光来自原作后期。原 `post.gdshader` SHA256 为 `dafb32c811a5d71439befd5088705bd4ca5ad92caee2d0be2036bf69125318af`。这验证了后期复用与二维内容通路，不代表对绘制内容的美术质量定案。
