#!/usr/bin/env python3
"""
Clean /Users/stev/Dev/Automemory/data/raw/2026-04-07.md
Produces a deduplicated, noise-free summary of the day's work.
"""

import re
from collections import defaultdict

INPUT  = '/Users/stev/Dev/Automemory/data/raw/2026-04-07.md'
OUTPUT = '/Users/stev/Dev/Automemory/data/raw/2026-04-07-clean.md'

# ---------------------------------------------------------------------------
# Load and split into sections
# ---------------------------------------------------------------------------
with open(INPUT, 'r', encoding='utf-8') as f:
    raw = f.read()

sections_raw = re.split(r'\n(?=## )', raw)
if sections_raw and not sections_raw[0].startswith('## '):
    sections_raw = sections_raw[1:]

TS_PAT       = re.compile(r'^## (\d{2}:\d{2}:\d{2})')   # raw OCR section
SUMMARY_PAT  = re.compile(r'^## (\d{2}:\d{2})[^:\d]')   # HH:MM non-colon
SUMMARY_PAT2 = re.compile(r'^## (\d{2}:\d{2})$')         # bare HH:MM

def get_start_time(header):
    m = SUMMARY_PAT.match(header) or SUMMARY_PAT2.match(header)
    return m.group(1) if m else None

def is_raw_ocr(header):
    return bool(TS_PAT.match(header))

parsed = []
for sec in sections_raw:
    lines = sec.split('\n')
    header = lines[0]
    body   = lines[1:]
    parsed.append({
        'header':     header,
        'body':       body,
        'is_raw':     is_raw_ocr(header),
        'start_time': get_start_time(header),
    })

# ---------------------------------------------------------------------------
# Noise patterns for line-level filtering
# ---------------------------------------------------------------------------
# Lines matching any of these are dropped
NOISE_PATTERNS = [
    # macOS / App menu bar
    r'^(Chrome|微信|飞书|飞飞书|Lark)$',
    r'^(文件|塢辑|编辑|显示|历史记录|书签|个人资料|标签页|窗口|帮助|窗口帮助)$',
    r'^书签\s*个人资料$',
    # Lark sidebar icons & items
    r'^(消息|日历|区 云文档|云文档|邮箱|函邮箱|任务|•任务|工作台|通讯录|视频会议|收藏|知识库|OKR|更多)$',
    r'^(飞书People|多维表格|审批|飞连|历史记录|帮助|三消息|三 消息)$',
    r'^(Q 搜索|Q 报素|Q 淡素).*$',
    r'^(门 添加快捷方式|门 添加快速方式|◎ L3-秘密|！最近修改：.*)$',
    r'^(ByteDance|◎ 清晰表达，避免过度缩写和堆砌高级悠词汇)$',
    r'^(1① 清晰表达.*|◎ 清晰表达.*)$',
    r'^[12] 分享$',
    r'^(品?通讯录|号 视须会议|圖 视须会议|视须会议|食收藏|a 知识库|© OKR|E 多维表格|88 工作台|2[：: ]通讯录|引 知识库)$',
    r'^(88 工作台|g 工作台|2：通讯录|2通讯录)$',
    r'^(\+6书People|X飞连|w 审批|日 多维表格|飞书People|飞连)$',
    # VS Code explorer
    r'^(EXPLORER|AUTOMEMORY|OUTLINE|TIMELINE)$',
    r'^[>v] (bin|data|memory|raw|tmp|docs|benchmark-images|node_modules|src|tests_|AUTOMEMORY|superpowers)$',
    r'^(> OUTLINE|> TIMELINE|> bin|v data|v memory|v raw|v tmp|v docs|v src)$',
    r'^(TS|｛｝|\{\}|~|r|m|四|T|w|\d{1}) [\w\-\.]+\.(ts|json|md|jpg|png|zip)$',
    r'^(gitignore|package-lock\.json|package\.json|tsconfig\.json)$',
    # VS Code status bar
    r'^(L\d+\.col\d+|Ln \d+ Col \d+|Spacesy \d+|UTF-8|LE)$',
    r'^\(\} (Markdown|TypeScript)$',
    r'^In\d+[\. ]Col\d+',
    r'^In\d+ Col\d+',
    # Browser tab / navigation noise
    r'^(ollama gemma 4- Google|900gle|discord|futnext|Claude|Claude \(MCP\)|Readhub|R Readhub)$',
    r'^(gemma4:[a-z0-9]+|ollama e4b- Google 搜索|ollama \w+ Google 搜索)$',
    r'^(\[New\] TikTok直\.|DMT项目：\d+\.\d+\.\d+第\.)$',
    r'^(⑤ TT大盘|③ TT大做|A Steve 的看板|A 订阅养板.*|A 订阅養板.*)$',
    r'^bytedance\.\w+\.larkoffice\.com.*$',
    r'^(tiktok-row\.?|futbin|豆包|User Product & Gaming 的.*)$',
    r'^(×|✕)$',
    # macOS menu bar date stamps
    r'^の\s*[。]?\s*\d+\s*4月\d+日',
    r'^4月\d+日周[一二三四五六日]\s+\d{2}:\d{2}$',
    r'^[0-9]{2}°C$',
    # Lark message list previews (HH:MM timestamps alone)
    r'^\d{2}:\d{2}\.?$',
    # Screen separator
    r'^--- Screen ---$',
    r'^---\s*$',
    # UI noise
    r'^(Screen capture and Gemma.*|Queue another message\.\.\.|Oueue another message\.\.\.|Edit automatically|</? ?Edit automatically)$',
    r'^\* (Tinkering|Crafting|Writing)\.\.\.$',
    # OCR garbage – single or few meaningless chars
    r'^[囚米匹个⑦㗊𠃋⑤]+$',
    r'^[囻圖四丰]+$',
    r'^[a-zA-Z0-9]$',
    r'^[的水米D a G 。、，]{1,3}$',
    r'^[• ]*[A-Z]{1,2}$',
    # Lark doc nav breadcrumb
    r'^[＞>] 李洋 [＞>] Live SMB Weekly Meeting \d+.*$',
    r'^Live SMB Weekly Meeting [Xx×]$',
    # Lark comment UI
    r'^(3 33 TikTok LIVE Use\.\.|縮辑|擒辑~|评论 （\d+）|文稿|口 所有书签)$',
    r'^(𠃋 縮辑|𠃋 擒辑~)$',
    # Code block artifacts & repeated metadata
    r'^# 工作记[录眾象泶]$',
    r'^0:\s*[0D]$',
    r'^(aude-code-|main\.zip|觀屏|艾禍)$',
    r'^data > memory.*$',
    r'^[•\s]*\d{4}-\d{2}-\d{2}\.md\s*[-_/].*$',
    # Calendar / lark message list items mixed in
    r'^(4月|4月 月\w*)$',
    r'^\d{1,2}\s+\d{1,2}$',
    r'^[12]\d\s+[12]\d[12]\d[12]\d$',
    r'^\d{3}/\d{3}[>）]\s*$',
    r'^[12]\s+\d{3}/\d{3}[>）].*$',
    # Specific noise strings
    r'^(ACUO|GIF|E：c\.|SEmE|G|D|p0|k|oK)$',
    r'^o[Kk]$',
    # Lark sidebar group items
    r'^(基础|基础&工具|游戏|camng|camina|Gaming|齐心协力|线\])$',
    r'^(TTLI|Live Gami|设计定稿|TTLive-U|User&Ga|epik|TD|李度)$',
    r'^(基础设计评审.会前阅读.+|还有\d+个日程|现在|审批\s*矶器人|审批 矶器人)$',
    # Numbers that are just file explorer line numbers
    r'^\d{1,3}$',
    # Trailing OCR noise from summaries
    r'^式\d+$',
    r'^不了家.*$',
    r'^apital Tower',
    r'^打开麦克员$',
    r'^正在讲语$',
    r'^正在讲话.*$',
    r'^[③②①⑧]+[）)。]?.*$',
    r'^[•]\s*[Cc]\+\+.*$',
    # VS Code explorer file items
    r'^[rv▶▼] \d{4}-\d{2}-\d{2}',
    r'^[YV▼v]\s*(AUTOMEMORY|data|raw|tmp|docs|memory|src|bin)$',
    r'^[▶>\^] (OUTLINE|TIMELINE|bin|node_modules|superpowers)$',
    r'^(screenshotcme|screansnotcme|\._tests_|_tests_)$',
    r'^\.gitignore$',
    r'^16 main:[A-Z][a-z]\d*$',
    r'^[⑧⑫][2A][A0]\d*$',
    r'^品$',
    r'^[2M]\.\s*(M|茶|Screen|Automemory).*$',
    r'^日$',
    r'^色$',
    r'^screen capture and Gemma context me\.\.\.$',
    r'^[▶>]+\s*(AUTOMEMORY|superpowers|OUTLINE|TIMELINE)$',
    r'^(Y AUTOMEMORY|¥ \d{4}|¥ raw|¥ memory|¥ tmp|¥ docs)$',
    r'^v(data|raw|tmp|docs|memory|src)$',
    r'^[rv][A-Z]\s+\d{4}',
    r'^(vstmp|vdocs|vdata|vsrc)$',
    r'^vocr',
    r'^feishu_[A-Z]_',
    r'^ide_original\.',
    r'^message_original\.',
    r'^calendar_original\.',
    r'^(c|Z|T|w|r) (calendar|feishu|ide|message)',
    r'^\d{19}-screen',
    r'^screansnotcme$',
    # Lark message list items that sneak through
    r'^[A-Za-z\u4e00-\u9fff]{2,15}[\s\u4e00-\u9fff]*\d{2}:\d{2}\.?$',
    r'^.*：.{5,50}\d{2}:\d{2}\.?$',
    r'^(AMl|AML|ILEE6|BS)$',
    r'^[◎•]\s*(公开|知识库)$',
    r'^(陆梦思：|定朋提醒：|剪映战略|TikTok Gaming|国际化基础|上海-网球).*$',
    # Numbers-only lines (file line numbers from VS Code)
    r'^\d{2,3}$',
    # Remaining summary body noise
    r'^[（\(][｝\}]\s*(Markdown|TypeScript).*$',
    r'^\(\}\s*(Markdown|TypeScript).*$',
    r'^の$',
    r'^cQ$',
    r'^2o 团$',
    r'^五金有 \d{4}$',
    r'^王金[鑫指存度] \d{4}$',
    r'^Aa$',
    r'^2[，,]\s*$',
    r'^\+ C\. ng\.\.\.$',
    r'^D\d{4}-\d{2}-\d{2}\.md$',
    r'^‹ Edit automatically$',
    r'^wfraw$',
    r'^2026-04-07imd.*$',
    r'^#2026-04-07 工作记录$',
    r'^##19:13（技木性能回顾与优化）$',
    r'^¥ \d{4}-\d{2}-\d{2}\.md$',
    r'^\d{19}-screen[O0]\.',
    r'^VSrc$',
    r'^B\.$',
    r'^22:01 - 22:02（掌播记录）$',
    r'^BRAM \d+$',
    r'^（eval:1: no matches found',
    r'^\[rerun: b[0-9]+\]$',
    r'^OUT$',
    r'^Modified$',
    r'^22:01 - 22:02（掌播记录）$',
    r'^1272$',
]

NOISE_COMPILED = [re.compile(p) for p in NOISE_PATTERNS]

def is_noise_line(line):
    s = line.strip()
    if not s:
        return False  # blank lines handled separately
    for pat in NOISE_COMPILED:
        if pat.match(s):
            return True
    return False

def collapse_blanks(lines):
    """Collapse multiple consecutive blank lines into one, strip trailing."""
    result = []
    prev_blank = False
    for line in lines:
        blank = line.strip() == ''
        if blank:
            if prev_blank:
                continue
            prev_blank = True
        else:
            prev_blank = False
        result.append(line)
    while result and result[-1].strip() == '':
        result.pop()
    return result

# Additional patterns to clean WITHIN summary bodies
SUMMARY_INLINE_NOISE = re.compile(
    r'(--- ?Screen ?---|'
    r'の\s*[。]?\s*\d+\s*4月|'
    r'# 工作记[录眾象泶]|'
    r'0:\s*[0D]|'
    r'[</]+\s*Edit automaticall|'
    r'/ Edit automaticall|'
    r'Queue another message\.\.\.|'
    r'Oueue another message\.\.\.|'
    r'Screen capture and Gemma|'
    r'\* Tinkering\.\.\.|'
    r'\* Crafting\.\.\.|'
    r'4月\d+日周[一二三四五六日]\s+\d{2}:\d{2}|'
    r'data > memory|'
    r'\d{4}-\d{2}-\d{2}\.md\s*[-_/]|'
    r'\d{2} 4月7日周二|'
    r'Ln\s*\d+[., ]\s*Col\s*\d+|'
    r'In\d+[\. ]\s*Col\d+|'
    r'\(\}\s*Markdown|'
    r'\(\}\s*TypeScript'
    r')'
)

EMBEDDED_HEADER = re.compile(r'^##\s*\d{2}:\d{2}')  # embedded section headers in body

def clean_summary_body(body_lines):
    out = []
    skip_embedded = False
    for line in body_lines:
        # Skip embedded ## section headers and everything after them until blank
        if EMBEDDED_HEADER.match(line.strip()):
            skip_embedded = True
            continue
        if skip_embedded:
            # Resume after a blank line following an embedded header block
            if line.strip() == '':
                skip_embedded = False
            continue
        if SUMMARY_INLINE_NOISE.search(line):
            continue
        if is_noise_line(line):
            continue
        out.append(line.rstrip())
    return collapse_blanks(out)

# ---------------------------------------------------------------------------
# 1. Deduplicate summary sections – group by start HH:MM
# ---------------------------------------------------------------------------
summary_groups = defaultdict(list)
for sec in parsed:
    if sec['start_time']:
        summary_groups[sec['start_time']].append(sec)

def score_summary(sec):
    header_words = len(sec['header'].split())
    body_len = sum(len(l) for l in sec['body'])
    return (header_words, body_len)

best_summaries = {t: max(v, key=score_summary) for t, v in summary_groups.items()}
sorted_times = sorted(best_summaries.keys())

# ---------------------------------------------------------------------------
# 2. Tech performance section – raw OCR around 20:54
# ---------------------------------------------------------------------------
TECH_KW = ['GPU 直接拉满', 'GPU直接拉滿', 'GPU是脉冲式', 'GPU 是脉冲式',
           'Vision OCR 几乎不吃', 'SUMMARIZE_INTERVAL', '推理时 GPU 内存',
           'Neural Engine', '内存峰值']

def has_tech(sec):
    t = '\n'.join(sec['body'])
    return any(k in t for k in TECH_KW)

tech_candidates = [s for s in parsed if s['is_raw'] and has_tech(s)]
tech_section = max(tech_candidates, key=lambda s: len('\n'.join(s['body']))) if tech_candidates else None

# Key tech lines to keep from raw OCR
TECH_KEEP = re.compile(
    r'(CPU|GPU|RAM|内存|推理|Vision OCR|Gemma4|脉冲|Neural Engine|'
    r'SUMMARIZE_INTERVAL|npm start|npn start|echo .Service started|'
    r'Service started|Bash Clean|rm -f|gemma4|ocr|screencapture|'
    r'16GB|1\.4GB|<1%|~16GB|97-99%|128GB|850MB|11GB|1\.5s|2-9s|'
    r'Edit config|SUMMARIZE|300|90_?[0-9]+|386|总结|关键发现|'
    r'节点|Nodeljs|Node\.js|CPU占用|CPU 占用|Metal)'
)

TECH_WHITELIST = re.compile(
    r'(CPU|GPU|RAM|内存|推理|Vision OCR|Gemma4|脉冲式|Neural Engine|'
    r'SUMMARIZE_INTERVAL|npm start|npn start|Service started|'
    r'Bash (Clean|Verify|Monitor)|rm -f|echo|sleep|ps aux|awk|'
    r'16GB|1\.4GB|<1%|~16GB|97-99%|128GB|850MB|11GB|1\.5s|2-9s|'
    r'Edit config\.ts|SUMMARIZE|总结|关键发现|'
    r'Node\.?js|CPU占用|CPU 占用|Metal|PID:|MEM:|CPU:|'
    r'推理时|推理结束|屏间隔|截图间隔|Tinkering|rerun|'
    r'那我们跑|改回5分钟|触发6次|跑个半个小时|CPU 和GPU|'
    r'处理速度|流水线|流水|耗时|服务|服务启动|启动命令|'
    r'后台监|验证|性能观察|优化建议|关键发现|磁盘压力|'
    r'Atomic Chat|llama-server|Ollama|ollama|模型|加载)'
)

def filter_tech_line(line):
    s = line.strip()
    if not s:
        return True  # keep blanks for now
    # Drop file tree & explorer noise
    if re.match(r'^[>v▶▼] ', s):
        return False
    if re.match(r'^(TS|｛｝|\{\}) ', s):
        return False
    if re.match(r'^(AUTOMEMORY|EXPLORER|Automemory|Y AUTOMEMORY|¥ )$', s):
        return False
    if re.match(r'^[rv▶▼] \d{4}-\d{2}-\d{2}', s):
        return False
    if re.match(r'^[vY▼] (data|raw|tmp|docs|memory|src|bin|AUTOMEMORY)', s):
        return False
    if re.match(r'^(v|¥|Y)(data|raw|tmp|docs|memory|src)', s):
        return False
    if re.match(r'^\d{19}-screen', s):
        return False
    if re.match(r'^(feishu_|ide_original|message_original|calendar_original)', s):
        return False
    if re.match(r'^(c|Z|T|w|r) (calendar|feishu|ide|message)', s):
        return False
    if re.match(r'^(screansnotcme|_tests_|\.gitignore|vocr)', s):
        return False
    if is_noise_line(line):
        return False
    if SUMMARY_INLINE_NOISE.search(s):
        return False
    # Scene/OCR meta headers
    if s.startswith('**场景：**') or s.startswith('**OCR 内容：**'):
        return False
    # Filter out paths and memory file re-OCR content
    if re.match(r'^(¥|Y|v)\s+\d{4}', s):
        return False
    if re.match(r'^(¥|Y)\s+(raw|tmp|docs|memory|src|data)', s):
        return False
    if re.match(r'^(VSrc|¥ Src|Y Src)$', s):
        return False
    if re.match(r'^#+\s*\d{2}:\d{2}', s):
        return False
    if re.match(r'^data>memory', s):
        return False
    if re.match(r'^#\s*2026-04-07', s):
        return False
    if re.match(r'^\d{19}-screen', s):
        return False
    if re.match(r'^\[rerun:', s):
        return False
    if s in ('OUT', 'Modified', 'BRAM 12868,', '2026-04-07.md', 'wfraw',
             'Queue another message.', 'D2026-04-07.md'):
        return False
    if re.match(r'^D2026-04-07', s):
        return False
    if re.match(r'^2026-04-07imd', s):
        return False
    if re.match(r'^‹ Edit', s) or re.match(r'^</ Edit', s):
        return False
    if s.startswith('+ C. ng') or s.startswith('+ C.ng'):
        return False
    if re.match(r'^\+ [A-Z]\. [a-z]+', s):
        return False
    if re.match(r'^\[rerun:', s):
        return False
    if re.match(r'^\d{19}-screen', s):
        return False
    if re.match(r'^[（\(][｝\}]\s*(package|json)', s):
        return False
    if s in ('（｝ package.json', '（｝ package-lock.json'):
        return False
    # Filter memory file re-OCR content that leaked into the tech section
    if re.match(r'^BRAM \d+', s):
        return False
    if re.match(r'^（eval:1:', s):
        return False
    # Only include lines with meaningful tech content
    if len(s) <= 2:
        return False
    return True

# ---------------------------------------------------------------------------
# 3. SMB document content – use the rich summary sections instead of raw OCR
#    Supplement with a few unique raw OCR lines that have real doc data
# ---------------------------------------------------------------------------
# The summary sections (20:54-21:01 range) already have the doc content summarized.
# For additional raw doc lines, we look at the raw OCR sections showing the Lark doc.

SMB_DOC_SECTIONS = []  # raw OCR sections specifically showing the doc
SMB_DOC_KW = ['Live SMB Weekly Meeting 260407', 'Live SMB Weekly Meeting\n',
               'To-do Last week', "Neal's Update", "Neal' s Update",
               'Global Market', 'US Market', 'MENA Market',
               '核心指标及 OKR', '本周进展', '重点行业突破',
               '汽车行业', '线上行业', '产品进展']

for sec in parsed:
    if sec['is_raw']:
        t = '\n'.join(sec['body'])
        if sum(1 for k in SMB_DOC_KW if k in t) >= 2:
            SMB_DOC_SECTIONS.append(sec)

# Patterns that indicate we're in actual document content (not Lark chat)
# We'll only keep lines that look like agenda items, metric data, or bullet points
DOC_CONTENT_RE = re.compile(
    r'(\d+\.\s*(To-do|Neal|Global|US Market|MENA|重点行业|汽车|线上行业|产品进展)|'
    r'^\d+\.\d+\s|'
    r'核心指标及 OKR|'
    r'本周进展|'
    r'(P[012]（|P[012]\（)|'
    r'(DAU|WoW|April Goal|Q2 Goal|Weekly Trend)|'
    r'(线索数|渗透率|开播UV|看播渗透|Meaningful 作者|Ban Rate)|'
    r'(load实验|NR/封禁|机房迁移|标签生产)|'
    r'(Direction|Main Target|Weekly Progress)|'
    r'(单店孵化|品牌陪跑|Showcase|Proton|Perodua|BYD|chery|Ford|Volkswagen|Mitsubishi)|'
    r'(冷启动|线索破蛋|成材率|陪跑|社群)|'
    r'(KYB|KYC|Calendly|Creator Code|eCPM|Ops Bot|FYP)|'
    r'(AML|eKYC|STM|沙特|CRI 模型|SOF)|'
    r'(服务商|Aimotion|吉隆坡|经销商)|'
    r'(公会|主播运营|分层运营|PGC)|'
    r'(Supercell|MMP 归因|Attribution|游戏详情页)|'
    r'(LATAM|拉美|巴西|马来|东南亚)|'
    r'(SMB：|Service \+能力|用户侧重构|DM 会话数|一级页展示)'
    r')'
)

smb_doc_lines_seen = set()
smb_doc_lines = []

# First: get the document table of contents (agenda) from the raw OCR
for sec in SMB_DOC_SECTIONS:
    in_toc = False
    for line in sec['body']:
        s = line.strip()
        if not s:
            continue
        if 'Live SMB Weekly Meeting 260407' in s and 'To-do Last week' not in s:
            in_toc = True
            continue
        if in_toc:
            # Table of contents ends when we see non-numbered content
            if re.match(r'^\d+[\.\s]', s) or re.match(r'^\d+\.\d+', s):
                if s not in smb_doc_lines_seen:
                    smb_doc_lines_seen.add(s)
                    smb_doc_lines.append(s)
            elif s in ('', ):
                continue
            else:
                in_toc = False

# Second: grab specific document content lines
SPECIFIC_DOC_NOISE = re.compile(
    r'^(4月|Chrome|文件|塢辑|编辑|显示|历史记录|书签|个人资料|标签页|窗口|帮助|ByteDance|'
    r'门 添加|◎ L3|！最近修改|2 分享|1① 清晰|◎ 清晰|User Product|ollama|gemma4:|'
    r'Readhub|Claude|discord|900gle|futnext|tiktok-row|futbin|豆包|'
    r'\[New\] TikTok|DMT项目|TT大|Steve 的看板|订阅養板|19 20|28 27|'
    r'a$|ByteDance|Live SMB Weekly Meeting [Xx]|3 33 TikTok|縮辑|擒辑|'
    r'评论 \（|文稿|口 所有书签|aude-code-|main\.zip|觀屏|艾禍|'
    r'[12]°C|Q$|4月\d+日周|--- Screen|---$|の\s*[。]|'
    r'王金[鑫存度店段]|五金|还金|ACUO|GIF|E：c\.|IAP|KING YOUR|'
    r'OVE this|TikTok Service\+|做大IP|五会店|五金自)'
)

def is_near_duplicate(candidate, seen_lines, threshold=0.85):
    """Simple near-dedup: skip if any existing line shares 85%+ of chars."""
    c = set(candidate)
    for existing in seen_lines:
        e = set(existing)
        if not c or not e:
            continue
        overlap = len(c & e) / max(len(c), len(e))
        # Also check prefix similarity for long lines
        min_len = min(len(candidate), len(existing))
        if min_len > 20:
            prefix_match = sum(a == b for a, b in zip(candidate[:min_len], existing[:min_len])) / min_len
            if prefix_match > 0.9:
                return True
        if overlap > threshold:
            return True
    return False

# Additional noise patterns for SMB doc lines
SMB_EXTRA_NOISE = re.compile(
    r'^(\*\*场景：\*\*|\*\*OCR 内容：\*\*|据暂时还没有刷新|'
    r'单店孵化计划\+社群ca\.\.|'
    r'沟通时请保持|Aa$|hi$|回$|mN8理|OMow|2020-W12|'
    r'索规模也有轻微|川$|F9 |李洋\s*\d+小时前|于正宜\s*\d+小时前|'
    r'白泽\s*\d+小时前|王金[鑫存度].*小时前|'
    r'有点反常|mark to-do|这个是啥实验|'
    r'主端会不定期|FYP 的曝光量级简称|每次一限制|且$|'
    r'\[图片\]|Meaningful 作者 NR 率太高|这周请 @|区域这边把|'
    r'可以放在治理周会|已经被保护了|US直描大盘近一个月整体开报|'
    r'load实验有关$|截止3/31$|'
    r'(P[0-9]（[重愛婆要斐斐常控]+）|P[0-9]（日常监控）)[\,，\s•]*$|'
    r'^\d+ ator:|^[89] ator:|'
    r'^(Direction$|Main Target$|Weekly Progress Updates$|'
    r'Showcase推广：$|Showcase视频|Showcase梯度规范|'
    r'提升DAU看播时长$|日开播5\+线索数作$|'
    r'迭代备播链路和素材以提升5\+线索数成才率$|'
    r'DAU人均看[摇播]时长&线索数$|'
    r'Ops Bot（飞书机器人）[。\-\.]\s*完成度 80%[，,。\.\-]+$|'
    r'Ops Bot（飞书机器人）-完成度 80%[，。\s]*[-]?$|'
    r'用户侧重构[项項]目于3/31上线$|'
    r'面中台相同的 DAU 看摇时长\。$|'
    r'[KK][YY][BC]认证率 2\.75%->3\.5%$|'
    r'本期将为升级至RBA的KYB认证主[摇播描]解锁[\.…]*$|'
    r'本阴将为升级至RBA|'
    r'KYC\+行业认证上线，认证率达到 8%$|'
    r'P2（日常监控）[•，\s]*$|'
    r'P1（重[婆斐]）$|'
    r'留资大盘作者被Ban[率罕][\|｜]Ban Rate$|'
    r'开播UV 44\.5K-> 53K$|'
    r'莫型跑通，聚焦LATAM进行门店实地$|'
    r'家单店模型标杆，周线索数5作者$)'
)

for sec in SMB_DOC_SECTIONS:
    for line in sec['body']:
        s = line.strip()
        if not s:
            continue
        if SPECIFIC_DOC_NOISE.match(s):
            continue
        if SMB_EXTRA_NOISE.match(s):
            continue
        if is_noise_line(line):
            continue
        if len(s) < 8:  # skip very short lines
            continue
        if DOC_CONTENT_RE.search(s):
            if s not in smb_doc_lines_seen:
                # Near-dedup check (only against last 30 lines to save time)
                if not is_near_duplicate(s, list(smb_doc_lines_seen)[-30:]):
                    smb_doc_lines_seen.add(s)
                    smb_doc_lines.append(s)

# Also get the doc content from the meeting-summary sections (they have it synthesized)
# This is already in summary sections 20:54-21:01 range

# ---------------------------------------------------------------------------
# 4. Calendar / meeting reminder – from raw OCR at 21:00 range
#    Focus ONLY on calendar/meeting items, not the SMB doc content
# ---------------------------------------------------------------------------
CAL_SECTIONS = [s for s in parsed
                if s['is_raw'] and '21:00' in s['header']
                and any(k in '\n'.join(s['body'])
                        for k in ['王瑞成', 'Playable', 'Live SMB Leaders',
                                  'Steve/冰冰', '胡冰冰', 'Capital Tower',
                                  '讨论下Playable', '正在讲话：'])]

# Only genuine calendar/meeting items, NOT the full SMB doc text
CAL_KEEP = re.compile(
    r'^(王瑞成：|讨论下Playable|Live SMB Leaders$|'
    r'Steve/冰冰[k/]|胡冰冰：|正在讲话：(Singapore|Shenzhen)|'
    r'Capital Tower|Singapore-Capital Tower|'
    r'James Wang\|?|@SG\s*[Ii]|in stillness|wisdom arises|'
    r'Weekly一行重点( \d+)?$|黄钰乔：Hi @所有人|'
    r'白泽：周会|PTE SET Ops Assist|颜乐驹：@|'
    r'李林游：具体每个|汤菲菲：26-04|Mira [机航]器人|'
    r'Activity Create Notification|【筹备组】游戏产研|'
    r'设计评审$|上海-网球社 公开|'
    r'无标题$|Gaming：$'
    r')'
)

cal_lines_seen = set()
cal_prefixes_seen = set()  # for prefix-based near-dedup
cal_lines = []

def cal_prefix_key(s, n=20):
    """Return first n chars stripped of trailing punctuation for prefix dedup."""
    return re.sub(r'[.。…\.]+$', '', s)[:n]

for sec in CAL_SECTIONS:
    for line in sec['body']:
        s = line.strip()
        if not s:
            continue
        if s.startswith('**场景：**') or s.startswith('**OCR 内容：**'):
            continue
        if is_noise_line(line):
            continue
        if SPECIFIC_DOC_NOISE.match(s):
            continue
        if CAL_KEEP.match(s):
            prefix = cal_prefix_key(s)
            if s not in cal_lines_seen and prefix not in cal_prefixes_seen:
                cal_lines_seen.add(s)
                cal_prefixes_seen.add(prefix)
                cal_lines.append(s)

# ---------------------------------------------------------------------------
# Build output
# ---------------------------------------------------------------------------
out = []

out.append('# 2026-04-07 工作记录（清洗后）')
out.append('')
out.append('> 原始文件 30877 行 → 清洗后保留核心内容。')
out.append('')
out.append('---')
out.append('')
out.append('## 工作时段汇总')
out.append('')

for t in sorted_times:
    sec = best_summaries[t]
    header = sec['header']
    body = clean_summary_body(sec['body'])
    out.append(header)
    out.extend(body)
    out.append('')

out.append('---')
out.append('')
out.append('## 技术性能数据（20:54）')
out.append('')

if tech_section:
    tech_lines = [l for l in tech_section['body'] if filter_tech_line(l)]
    tech_lines = collapse_blanks(tech_lines)
    out.extend([l.rstrip() for l in tech_lines])
else:
    out.append('（未找到性能数据段）')
out.append('')

out.append('---')
out.append('')
out.append('## 日程提醒（21:00）')
out.append('')
out.extend(cal_lines)
out.append('')

out.append('---')
out.append('')
out.append('## Live SMB Weekly Meeting 260407（文档内容）')
out.append('')
out.extend(smb_doc_lines)
out.append('')

# ---------------------------------------------------------------------------
# Write output
# ---------------------------------------------------------------------------
text = '\n'.join(out)
with open(OUTPUT, 'w', encoding='utf-8') as f:
    f.write(text)

total = len(out)
print(f'Done → {OUTPUT}')
print(f'Total lines: {total}')
print(f'Summary sections: {len(sorted_times)}')
print(f'Tech section found: {tech_section is not None}')
print(f'Calendar lines: {len(cal_lines)}')
print(f'SMB doc lines: {len(smb_doc_lines)}')
