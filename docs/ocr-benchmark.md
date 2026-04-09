# OCR Benchmark — Full Results

Model: `qwen3.5:0.8b` via Ollama, `think: false`

**Prompt:**
```
请提取屏幕上所有可见的文字内容，并简要描述当前屏幕的工作场景（在用什么应用、在做什么）。

请按以下格式输出：

**屏幕描述：** （描述当前工作场景）

**文字内容：**
（列出所有可见文字）
```

Screenshots taken at 5s intervals (16:39:04 - 16:39:20), original resolution 3456x2234 (Retina).

## Summary

| Variant | Shot 1 (IDE) | Shot 2 (Chat) | Shot 3 (Calendar) | Shot 4 (Message) |
|---------|-------------|--------------|------------------|-----------------|
| A: 1440px q85 | 16.2s / 6346ch / 241KB | 13.6s / 2796ch / 253KB | 14.1s / 2121ch / 376KB | 3.5s / 741ch / 299KB |
| B: 2048px q90 | 14.2s / 3431ch / 411KB | 3.4s / 501ch / 454KB | 15.2s / 2876ch / 712KB | 3.4s / 619ch / 535KB |
| C: Full q90 | 5.1s / 1212ch / 848KB | 14.5s / 2149ch / 984KB | 14.3s / 2380ch / 1597KB | 3.4s / 605ch / 1169KB |
| D: Original PNG | 5.5s / 1114ch / 1289KB | 4.9s / 967ch / 3182KB | 14.9s / 2229ch / 3602KB | 15.0s / 1858ch / 3440KB |

---

## A: 1440px q85

### Shot 1: VS Code / IDE (241KB, 16.2s, 6346 chars)

**屏幕描述：**
图片显示的是一个名为“Automemory”的IDE界面，正在处理图片OCR（光学字符识别）任务。左侧目录树显示了文件路径如 `screen0.jpg`，右侧是OCR结果分析页面，显示了各种模型的对比效果、清理数据步骤以及服务运行指令。

**文字内容：**
AUTOMemory
1 177550770386-screen0.jpg
AUTOMemory
Screen capture and Gemma ...
2026-04-07.md
SCREEN CATEGORIES
AUTOMEMORY
screenshots from 1600px to 2000px
Screen capture and Gemma context me...
Bash Run OCR comparison on 4 image variants
IN cat > /tmp/ocr_compare.ts << 'SCRIPT'
import { readFile } from 'nodefs/promises';;
OUT[1]:
[A:1440px q85] File: /tmp/test_A_1440_q85.jpg(293KB, base64:390KB)
Time: 13.5s | Content length: 3747 chars
Bash Run OCR comparison on 4 image variants
IN [cat> /tmp/ocr_compare.ts << 'SCRIPT'
import { readFile } from 'nodefs/promises';;
OUT[1]:
[A:1440px q85] File: /tmp/test_A_1440_q85.jpg(293KB, base64:390KB)
Time: 13.5s | Content length: 3747 chars
Bash Clean data for fresh test
IN rm -f data/tmp/*.png data/tmp/*.jpg data/raw/*.md data/*.md/
OUT(eval):1: no matches found: data/tmp/*.png
cleaned
[runer: b1]
Read summaryers.ts(lines 48-67)
Edit summaryers.ts
Modified
options: { num_predict: 4096},
options: { num_ctx: 131072 },
Bash Run service for 2 minutes
IN npm start 2&>61 &
sleep 130 && $ (pgrep -f "tsx src/index.ts") 2>/dev/null
Effecting...
Queue another message...
+ Effecting...
(command (k4psvk))
多测几次，你接下去没5s一张，然后画20s截图，截图后，测这些几张图片都试试看
Bash Take 4 screenshots at 5s intervals
IN # Take screenshots every 5s for 20s = 4 screenshots
mkdirp -p /tmp/ocr_batch
for i in 1 2 3 4; do
177550770386-screen0.png
177550770386-screen0
1775507707386-screen0
177550770386-screen0
177550770386-screen0
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script
script

---

### Shot 2: Feishu Chat (253KB, 13.6s, 2796 chars)

**屏幕描述：**

屏幕显示的是一个名为“消息”的聊天界面，用户正在与多位联系人交流。界面左侧是消息列表，显示了过去会话的对话历史，包括关于服务抖等应用讨论、公司产品发布（TikTok Launch）的更新，以及一个标题为“客服”的在线游戏活动。右侧是实时聊天窗口，正在接收一条输入框，当前处于空位中，提示用户“沟通时需保持‘公开可接受’”，并且该消息已被发送。顶部状态栏显示时间为16:38，日期为“4月7日 周二”。整个界面带有水印，显示为“飞书”品牌。

**文字内容：**

18:63 | 94.7°C | 飞书
[8] 16:38
[4月7日 周二]

[4/4] 16:38

**【消息】108/109 [消息]**
**74B**

**Adam Wa**
**16:36**
[2/2] 23:15

**Zhang Zhen**
**16:36**
[2/2] 23:15

**王金鑫**
**16:36**
[2/2] 23:15

**Bao**
**16:36**
[2/2] 23:15

**Liang**
**16:36**
[2/2] 23:15

**王金鑫**
**16:36**
[2/2] 23:15

**Bao**
**16:36**
[2/2] 23:15

**基越**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Shi**
**16:36**
[2/2] 23:15

**LIVE Game**
**16:36**
[2/2] 23:15

**设计定型**
**16:36**
[2/2] 23:15

**TIli-v-e-u**
**16:36**
[2/2] 23:15

**TtLve-u**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**UserG&a**
**16:36**
[2/2] 23:15

**游戏厂商**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**[Gaming]**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23:15

**Gaming**
**16:36**
[2/2] 23

---

### Shot 3: Feishu Calendar (376KB, 14.1s, 2121 chars)

**屏幕描述：**
当前屏幕上显示的是一张日程管理软件的界面，显示了一个名为“2026年4月”的日历。日程表中包含每日的会议、活动安排，时间从02:00到23:00。日程列表左侧显示了各种用户信息，包括姓名、标签和日期。日程表右侧则列出了具体的会议时间、地点和活动详情。

**文字内容：**
2026年4月29日
2026年4月30日
2026年4月31日
2026年4月
2026年4月5日-11日
2026年4月
周（星期日）
周（星期一）
周（星期二）
周（星期三）
周（星期四）
周（星期五）
周（星期六）
2026年4月5日
2026年4月6日
2026年4月12日
2026年4月19日
2026年4月26日
2026年4月27日
2026年4月28日
2026年4月29日
2026年4月30日
2026年4月
20:02
10:00
18:00
09:00
03:00
11:00
19:00
10:00
04:00
12:00
20:00
11:00
05:00
13:00
12:00
10:00
08:00
14:00
22:00
13:00
07:00
15:00
23:00
14:00
08:00
16:00
10:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
03:00
18:00
17:00
11:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
15:00
22:00
20:30
14:00
17:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00
18:00
17:00
09:39
17:39
01:39
16:39
11:00
19:00
00:00
08:00
16:00
19:00
03:00

---

### Shot 4: Feishu Message (299KB, 3.5s, 741 chars)

**屏幕描述：**

当前屏幕是一个网页应用界面，看起来像是一个协作或管理工具。左侧是“消息”列表，列出了多个用户（如Adam Wa、吴东录、李彦霖等）以及他们的消息内容，例如“LIVE Creation>>TA”和“SMB Service协作沟通”。右侧是“LIVE Creation>TA”用户的消息详情页面，标题显示“4.7 岗位画像 update with @温贞”，主要内容关于“主播增长方向”、“可拓宽”和“协同对象”等职位的要求和经验要求。底部有一个“用户产品运营（AI直播创作工具）”的缩略图，下方有输入框和表情符号等工具栏。整体场景是团队成员或管理员在讨论或发布工作信息。

**文字内容：**

4.7 岗位画像 update with @温贞

1. 主播增长方向:
- 核心目标: 提高电脑开播工具的主播开播 UV 规模，重点推动中高端主播群体增长，通过策略撬动主播使用工具。
- 经验要求

2. 供应商方向:
- 核心目标: 搭建供应商平台，曝光供应商信息撮合线下成交，做好供应商入驻和管理，形成市场自动运转。
- 经验要求

3. 协同对象:
- 协同对象: 平台搭建阶段与产品侧、研发侧、合规链路（法务、财务、风控）等团队协作; 供应商入驻和协作过程中与外部客户沟通。

4. AI 能力: AI是加分项，非必要项;
  英语能力:B2.2 及以上，口语语可作为工作语言
  @用户产品运营(AI直播创作工具) 画像对齐 CC @Ken(已编辑)
用户产品运营(AI直播创作工具) 画像对齐

用户产品运营(AI直播创作工具) 画像对齐
你可阅读

沟通时请保持“公开可接受”

Aa

表情包

剪贴

拖拽

添加文件

更多

文件

表情符号

---

## B: 2048px q90

### Shot 1: VS Code / IDE (411KB, 14.2s, 3431 chars)

**屏幕描述：**

这是一张电脑屏幕上运行自动化脚本截图，显示的是“Gemma context me”（Gemma上下文分析）界面的“Screen capture and Gemma context me...” 页面。屏幕右侧有一个浏览器窗口，其中显示的是该页面的源代码，可以看到诸如 `# Take screenshots every 5s for 20s = 4 screenshots` 等 Ruby 代码。

**文字内容：**

**AUTOMEMORY**
**data**
**memory**
**raw**
**2026-04-07.md**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**tsconfig.json**
**docs**
**/tmp/ocr_batch**
**/tmp/test_A_1440_q85.jpg**
**/tmp/test_A_1440_q85.png**
**package-lock.json**
**package.json**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**package-lock.json**
**package.json**
**tsconfig.json**
**2026-04-07.md**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**screenshots every 5s for 20s = 4 screenshots**
**mkdir -p /tmp/ocr_batch**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1775550770386-screen0.png**
**1775550770386-screen0.png**
**1775550770386-screen0.jpg**
**1

---

### Shot 2: Feishu Chat (454KB, 3.4s, 501 chars)

**屏幕描述：**

当前屏幕显示了一个微信聊天窗口，主要聊天对象为“蔡李超”。聊天内容主要围绕“王金鑫”展开，讨论其游戏相关的问题，如“游戏看板”、“游戏”、“客服”等。文字内容中包含大量中文，如“游戏看板”、“王金鑫”、“客服”、“游戏”等。

**文字内容：**

蔡李超
游戏看板
游戏
基础工具
李超
游戏厂商
咪咪
[1632422376620351]
游戏
TTL-Live-U
User&Gam
游戏厂商
LIVE Gai
LiveGami
[1627511258576580]
设计定制
齐步协力
[1537189939535065]
[1516150869621628]
[1457177903080919]
设计
Gaming
[1372597272435020]
打开
Gaming
开心协力
Gaming
[1323191003156169]
艾
claw被改崩了。。
1条回复
王金鑫: claw被改崩了。。
🧐
为什么搞崩的
你需要的话我可以分享下我的运维操作。。。好像目前没出什么问题
主要还是clude这波升级
导致我
全盘过去很多工作都白了
具体咋说，晚饭交流下？

---

### Shot 3: Feishu Calendar (712KB, 15.2s, 2876 chars)

**屏幕描述：**

这是一个Apple生态系统内应用的工作界面，显示时间为4月5日23:08-4月11日23:14。当前页面似乎是日历或日程管理，列出了“2026年4月5日 - 11日”这个期间的日程安排。左侧是“日历”选项，显示当前是“4月”。右侧列出了从周一到周六的不同日子，并包含了标题为“44.7.0 iOS全量/Full Release”、“44.7.0 Android灰灰//Gray Release”等更新日志。

**文字内容：**

日 日历 会议室 预约活动
* 11 04-20-24-25
7 2016年4月-11日
今天 2026年4月5日-11日
44.7.0 iOS全量/Full Release 24-11-23-22
44.7.0 Android灰灰//Gray Release 21-11-19-18
44.8.0 封版//Code freeze 19-11-18-17
44.7.0 iOS全量/Full Release 18-11-16-15
44.7.0 Android灰灰//Gray Release 15-11-14-13
TT LIVE用户产品迭代 13-11-12-11
TT LIVE用户产品迭代 11-10-10
TT LIVE用户产品迭代 09-10-09
TT Live User Product 14-10-13-12
TT Live User Product 14-10-13-11
TT Live User Product 14-10-13-10
TT Live User Product 14-10-13-09
TT Live User Product 13-10-13-08
TT Live User Product 12-10-12-08
TT Live User Product 12-10-12-07
TT Live User Product 11-10-11-07
TT Live User Product 11-10-11-06
TT Live User Product 10-10-10-06
TT Live User Product 09-10-09-06
TT Live User Product 09-10-09-05
TT Live User Product 08-10-08-05
TT Live User Product 08-10-08-04
TT Live User Product 07-10-07-04
TT Live User Product 06-10-06-04
TT Live User Product 06-10-06-03
TT Live User Product 05-10-05-03
TT Live User Product 04-10-04-02
TT Live User Product 03-10-03-02
TT Live User Product 02-10-02-01
TT Live User Product 01-10-01-00
TT Live User Product 2026 Q1 Internal Quarterly Review 22-00-00
TT Live User Product 17-17-17-17
TT Live User Product 14-15-15-14
TT Live User Product 13-13-13-12
TT Live User Product 12-12-12-11
TT Live User Product 11-11-11-10
TT Live User Product 10-10-10-09
TT Live User Product 09-09-09-08
TT Live User Product 08-08-08-07
TT Live User Product 07-07-07-06
TT Live User Product 06-06-06-05
TT Live User Product 05-05-05-04
TT Live User Product 04-04-04-03
TT Live User Product 03-03-03-02
TT Live User Product 02-02-02-01
TT Live User Product 01-01-01-00

* 9-9
4 4 4
3 3
2 2
1 1
5 5
6 6
7 7
8 8
9 9
10 10
11 11
* 14-15-17-18
* 14-15-16-17
* 22-24-25
* 13-14-15
* 21-23
* 27-29
* 31-33
* 19-21
* 23-25
* 26-27
* 28-29
* 30-32
* 19-21
* 22-24
* 27-28
* 29-30
* 31-32
* 21-22
* 23-25
* 25-26
* 27-28
* 29-30
* 31-32
* 22-24
* 27-28
* 29-30
* 31-32
* 20-22
* 24-26
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 22-24
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 21-22
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-30
* 31-32
* 20-21
* 23-25
* 27-28
* 29-3

---

### Shot 4: Feishu Message (535KB, 3.4s, 619 chars)

**屏幕描述：**

在应用界面中，用户正在浏览一个名为“LIVE Creation>>TA”的微博或即时通讯应用，主要关注的是某个用户发布的内容，其标题为“4.7 岗位画像 update with @温寅”。左侧是消息列表和频道选择，右侧是内容详情页，包含了关于“岗位画像”的需求描述和“协同对象”、“AI能力”等信息。

**文字内容：**

```
LIVE Creation>>TA
16:37
消息

4.7 岗位画像 update with @温寅
16:37
```

1.  主播增长方向:
*   核心目标：提高电脑开播工具的主播开播 UV 规模，重点推动中高端主播群体增长，通过策略撬动主播使用工具。
*   经验要求：增长经验丰富但无直播经验者，重点关注 TT 站内视频素材投放、内部推广、线上线下活动等经验。

2.  供应商方向:
*   核心目标：搭建供应商平台，曝光供应商信息撮合线下成交，做好供应商入驻和管理，形成市场自动运转。
*   经验要求：有机构合作经验，如 0 到 1 搭建机构体系、开展机构合作项目。

3.  协同对象：与区域运营团队密切沟通，确保策略落地。

4.  其他

AI 能力：AI 是加分项，非必选项；

英语能力：B2.2 及以上，口语能作为工作语言

用户产品运营（AI直播创作工具）  画像对齐

CC @Ken (已编辑)

用户产品运营（AI直播创作工具）  画像对齐

---

## C: Full q90

### Shot 1: VS Code / IDE (848KB, 5.1s, 1212 chars)

**屏幕描述：**
在图像浏览器的一个会话中，显示了一个名为"Screen capture and Gemma context me..."的截屏内容。左侧是自动化存储管理器（Automemory）的数据结构视图，包括AUTOMEMORY文件夹下的数据存储如memory、raw和tmp等。中间是当前活动页面的内容摘要，右侧显示了一个文本框，内容包含关于OCR、Bash脚本、总结器修改以及服务执行指令等。整个界面使用了Windows的资源管理器，顶部有自动内存监控器的图标。

**文字内容：**
Screen capture and Gemma context me...
2026-04-07.md
图片清晰度能再提升吗？我们要先debug ocr
Bash Run OCR comparison on 4 image variants
IN cat > /tmp/orc_compare.ts << 'SCRIPT'
import { readFile } from 'node:fs/promises';
OUT
====================================================================
[ A: 1440px q85 ] File: /tmp/test_A_1440_q85.jpg (293KB, base64: 390KB)
Time: 13.5s | Content length: 3747 chars
有意思，结果出来了：
版本 大小 耗时 内容 评价
A: 1440px q85  293KB  13.5s  3747字  最详细，但有幻觉
B: 2048px q90  529KB  6.0s  1764字 结构清晰，文字准确
C: Full q90  1.1MB  4.7s  1337字 准确但较简洁
D: Original PNG  1.2MB  5.2s  1489字 准确，细节适中
发现：
A 虽然输出最多，但反而有更多幻觉（模型“脑补”了看不清的内容）
B 是最佳平衡点——文字识别准确，结构好，529KB体积可接受
C/D 全尺寸反而更简洁，可能是 0.8b 模型处理大图时 token 分配不够
推荐用 B: 2048px q90。要改吗？
command (k4psvkw)
多测几次，你接下去没5s 截一张，然后画20s 截图，截完后再，测这些图片都试试看
Bash Take 4 screenshots at 5s intervals
# Take screenshots every 5s for 20s = 4 screenshots
mkdirir - /tmp/orc_batch
for i in 1 2 3 4; do
Queue another message...
+ Effecting...

---

### Shot 2: Feishu Chat (984KB, 14.5s, 2149 chars)

**屏幕描述:**

这是一个聊天界面，显示了名为“蔡李超”的聊天窗口，与左侧的聊天列表相似，但右侧是主要对话区域。聊天列表显示用户有“金鑫”和“王金鑫”等名称。在右侧聊天内容中，用户“蔡李超”与“金鑫”之间发生了一系列对话，内容涉及游戏、商业、个人事务等话题。聊天框中有多个消息气泡，包含文字和表情符号。聊天内容似乎集中在英文文本中，例如“f*ck (已编辑)”、“claw被我改崩了。”、“claw被我改崩了。”、“主要还是clade这波升级”。整体氛围是即时通讯应用中的对话场景。

**文字内容：**

**李 林 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李 李

---

### Shot 3: Feishu Calendar (1597KB, 14.3s, 2380 chars)

**屏幕描述：**

这张图片显示的是一个苹果 iFlytek 飞书（Flibit）桌面时间的应用程序界面。屏幕左侧和右侧显示了日程安排表，中间是日历视图和任务管理区域，左侧的列表区域包含了用户的日程管理设置、个人任务、已读任务和订阅内容等分类。当前日期为2026年4月5日至11日期间，用户有大量的日程安排和待办事项。

**文字内容：**

**日程安排表相关文字：**
- 2026年4月-11日
- 5 6 7 8 9 10 11
- GMT+1 GMT+9 GMT-7 GMT-8
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
- 还有 2 项
-

---

### Shot 4: Feishu Message (1169KB, 3.4s, 605 chars)

**屏幕描述：**

当前屏幕显示的是"飞书"应用中的一个工作台视图，主要展示了一个名为“LIVE Creation<<TA”的新消息/文档页面，该页面内列出了关于岗位画像更新的技术要求、供应链方向等内容，以及一个视频预览图。左侧边栏显示了消息列表、任务列表、日程安排等信息，底部 Dock 栏显示了多个应用程序图标。

**文字内容：**

4.7 岗位画像 update with @温温

1. 主播增长方向:
- 核心目标: 提高电脑开播工具的主播开播 UV 规模，重点推动中高营收主播群体增长，通过策略撬动主播使用工具。
- 经验要求:

2. 供应商方向:
- 核心目标: 搭建供应商平台，曝光供应商信息撮合线下成交，做好供应商入驻和管理，形成市场自动运转。
- 经验要求:

3. 其他:
AI 能力: AI 是加分项，非必备项;
英语能力: B2.2 及以上，口语能作为工作语言
用户产品运营（AI直播创作工具）图像对齐
CC @Ken (已编辑)

可用阅读

【...用户产品运营（AI直播创作工具）图像对齐】

你可以阅读

---

**工作场景：** 用户正在使用飞书软件管理企业或团队内部的协作工作。屏幕上展示的内容包括更新后的岗位画像（直播技能要求）和相关的供应商合作信息，说明这可能是一个用于发布内部资讯、展示团队实力或进行人才招聘的场景。页面底部还显示了一个待阅读的任务预览。

---

## D: Original PNG

### Shot 1: VS Code / IDE (1289KB, 5.5s, 1114 chars)

**屏幕描述：**
用户正在使用 Chrome 浏览器，打开一个名为 "Screen capture and Gemma context me..." 的文本摘要窗口，该窗口记录了在图像对比测试（OCR）中使用了 Gemma 模型的分析过程。当前主要任务是在命令行中运行一系列操作，包括清理图片数据、重新运行对比实验以及生成截图，以评估模型在图像识别上的表现。

**文字内容：**
2026-04-07.md
图片清晰度再能提升吗？我们要不先debug orc
Bash Run OCR comparison on 4 image variants
IN
cat > /tmp/ocr_compare.ts << 'SCRIPT'
import { readFile } from 'node:fs/promises';
OUT
==================
[A: 1440px q85] File: /tmp/test_A_1440_q85.jpg (293KB, base64: 390KB)
Time: 13.5s | Content length: 3747 chars
有意思，结果出来了:
版本
大小
耗时
内容
评价
A: 1440px q85
293KB
13.5s
3747字
最详细，但有幻觉
B: 2048px q90
529KB
6.0s
1764字
结构清晰，文字准确
C: Full q90
1.1MB
4.7s
1337字
准确但较简洁
D: Original PNG
1.2MB
5.2s
1489字
准确，细节适中
发现:
A 虽然输出最多，但反而有更多幻觉（模型“脑补”了看不清楚的内容）
B 是最佳平衡点——文字识别准确，结构好，529KB 体积可接受
C/D 全尺寸反而更简洁，可能是 0.8b 模型处理大图时 token 分配不够
推荐用 B: 2048px q90。要改吗?
command (k4psvkg)
多测几次，你接下没5s 一张，然后画20s 截图，截完后再，测这么几张图片都试试看
Bash Take 4 screenshots at 5s intervals
IN # Take screenshots every 5s for 20s = 4 screenshots
mkdir -p /tmp/ocr_batch
for i in 1 2 3 4; do
Queue another message...
Command (k4psvkg)
+ Effecting...
+ Queue another message...
2026-04-07.md

---

### Shot 2: Feishu Chat (3182KB, 4.9s, 967 chars)

**屏幕描述:**

这是一个使用Apple MacBook Pro（M1或M2芯片）界面的多应用窗口，左侧是新闻客户端“消息”（Messages），右侧是微信（WeChat）聊天界面，底部是macOS操作系统的Dock栏。场景是一个多用户团队聊天环境，当前显示的是用户“蔡李超”与同事或合作伙伴的聊天记录，聊天内容涉及商业、游戏和内部沟通。

**文字内容：**

消息列表：
*   **Adam Wa:** 游戏看板
*   **詹娜:** 游戏看板
*   **王金鑫:** 游戏看板
*   **赛骏:** 基础 & 工具
*   **游戏厂商:** 游戏看板
*   **游戏Gamer:** Gaming
*   **齐心协力:** 游戏Gamer
*   **常:** 游戏Gamer
*   **[Gaming]:** Gaming
*   **David:** 齐心协力

主聊天列表：
*   **李林:** LIVE Game
*   **杨博文:** LIVE Game
*   **李林:** LIVE Creation<<<TA
*   **李林:** 审批 机器人
*   **李林:** 直播PM Group
*   **李林:** SMB Service协作沟通
*   **李林:** SMB推荐办公室 // Reco
*   **李林:** TikTok Launch - Core...
*   **李林:** [User Product] 2026 Q...
*   **蔡李超:** 具体咋说，晚饭交流下?

聊天内容：
*   f*ck（已编辑）
*   这
*   恢复了 😂
*   妈的。。感觉现在 claude 服务抖一抖，全球智商就要掉 10 个点。。
*   哎
*   claw 被我改崩了。。
*   1 条回复
*   | 回复 王金鑫：claw 被我改崩了。。
*   😂 😂 你怎么搞崩的
*   你需要的话我可以分享下我的运维操作。。好像目前没出什么问题
*   主要还是 claude 这波升级 😂
*   导致我 🥲
*   全盘 过去很多工作都白做了
*   | 回复 王金鑫：主要还是 claude 这波升级📝
*   具体咋说，晚饭交流下？

---

### Shot 3: Feishu Calendar (3602KB, 14.9s, 2229 chars)

**屏幕描述：**

用户正在使用“飞书”软件，查看2026年4月的日程安排界面。左侧的日历上标记了7日。日程表上方列出了2026年4月5日至11日的各个工作日，包括周五、周四、周五、周六，以及7日、8日、9日、10日、11日。日程表中的每个单元格都包含不同的事件或任务，如“44.7.0 iOS 全员发布//Phase Release”、“44.6.0 Android灰灰发布”等。日历下方左侧列出了用户“我管理的”、“我订阅的”和“我订阅的”等标签下的条目。在右下角的macOSDock中，有几个应用程序图标。

**文字内容：**

**2026年4月**
- **日期**: 5, 6, 7, 8, 9, 10, 11

**工作日 (2026年4月5日 - 11日):**
- 周五 (GMT+1)
- 周四 (GMT+9)
- 周五 (GMT+8)
- 周六 (GMT+8)

**工作日 (2026年4月5日 - 11日):**
- 周六 (GMT+1)
- 周五 (GMT+8)
- 周五 (GMT+9)
- 周六 (GMT+1)

**日程表事件/任务:**
- 12:00: 44.5.0  iOS 全量发布/Phase Release
- 09:39: 16:39
- 03:30: 11:00
- 09:00: 09:00
- 17:30: 01:39
- 10:00: 02:00
- 17:30: 16:39
- 14:30: 01:00
- 17:30: 16:39
- 10:00: 17:30
- 14:00: 00:00
- 15:00: 15:00
- 12:00: 20:00
- 11:00: 11:00
- 14:00: 00:00
- 15:00: 15:00
- 17:30: 00:00
- 17:30: 03:00
- 17:30: 18:00
- 02:00: 00:00
- 17:30: 00:00
- 17:30: 03:00
- 17:30: 03:00
- 10:00: 17:00
- 10:00: 17:00
- 02:00: 00:00
- 17:30: 02:00
- 17:30: 17:00
- 17:30: 03:00
- 18:00: 18:00
- 14:30: 20:00
- 15:00: 15:00
- 09:30: 00:00
- 17:00: 00:00
- 16:39: 17:30
- 10:30: 10:00
- 11:00: 00:00
- 11:00: 01:00
- 17:00: 16:00
- 10:00: 01:00
- 17:00: 16:00
- 17:30: 18:00
- 10:30: 18:00
- 10:00: 10:00
- 10:00: 10:00
- 17:00: 14:00
- 00:00: 15:00
- 13:30: 00:00
- 12:00: 12:00
- 12:00: 10:00
- 08:30: 11:00
- 13:30: 23:00
- 17:00: 14:00
- 14:00: 13:30
- 15:00: 15:00
- 13:00: 13:00
- 13:30: 10:00
- 13:30: 11:00
- 15:00: 15:00
- 09:39: 00:00
- 17:30: 00:00
- 13:00: 15:00
- 17:00: 16:00
- 10:30: 17:00
- 10:30: 18:00
- 17:00: 03:00
- 18:00: 18:00
- 12:00: 20:00
- 00:00: 15:00
- 15:00: 00:00
- 15:00: 15:00
- 16:00: 00:00
- 17:30: 00:00
- 17:30: 23:00
- 16:00: 00:00
- 15:00: 08:00
- 23:00: 00:00
- 16:39: 16:39
- 17:39: 01:39
- 17:39: 17:39
- 16:39: 16:39
- 00:39: 17:39
- 17:39: 01:39
- 17:39: 16:39
- 00:00: 00:00
- 00:00: 00:00
- 00:00: 23:00
- 00:00: 22:00
- 00:00: 00:00
- 00:00: 23:00
- 00:00: 00:00
- 15:00: 03:00
- 17:30: 00:00
- 00:00: 18:00
- 17:30: 00:00
- 00:00: 00:00
- 17:30: 22:00
- 18:00: 20:00
- 02:00: 17:00
- 17:30: 02:00
- 17:00: 17:00
- 14:00: 00:00
- 15:00: 15:00
- 10:00: 10:00
- 17:30: 00:00
- 17:30: 03:00
- 18:00: 18:00
- 17:00: 00:00
- 13:00: 12:00
- 00:00: 12:00
- 09:30: 00:00
- 17:30: 16:00
- 10:30: 17:00
- 10:30: 18:00
- 18:

---

### Shot 4: Feishu Message (3440KB, 15.0s, 1858 chars)

**屏幕描述：**

当前屏幕上显示的是一个名为“飞书”的多人协作聊天应用界面，具体为“LIVE Creation<<TA”频道的主播发言内容。左侧是聊天的消息列表，右侧是当前对话中吴东宇发布的一条直播相关消息，详细列出了主播的增长方向、需求等要点。界面顶部显示了“745”个未读消息，时间戳为“16:37”。

**文字内容：**

4.7 岗位画像 update with @温言
1. 主播增长方向：
    - 核心目标：提高电脑开播工具的主播开播 UV 规模，重点推动中高营收主播群体增长，通过策略带动主播使用工具。
    - 经验要求：可拓展：增长经验丰富但无直播经验者，重点关注 TT 站内视频素材投放、内部推广、线上线下活动等经验。
2. 供应商方向：
    - 核心目标：搭建供应商平台，曝光供应商信息撮合线下成交，做好供应商入驻和管理，形成市场自动运转。
    - 经验要求：
3. 协同对象：平台搭建阶段与产品侧、研发侧、合规链路（法务、财务、风控）等团队协作；供应商入驻和协作过程中与外部客户沟通。
4. AI 能力：AI 是加分项，非必填项;
    英语能力：B2.2 及以上，口语能作为工作语言
    🏗️📸用户产品运营（AI直播创作工具）画像对齐
CC @Ken (已编辑)
用户产品运营（AI直播创作工具）画像对齐
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍
👍

---

