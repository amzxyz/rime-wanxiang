-- super_segmentation.lua
--@amzxyz https://github.com/amzxyz/rime_wanxiang
-- 规则：
-- 1) 第 1 个 '：仅记录“现场”（baseline_head=当前整段输入，含你之前的手动分隔），记录起点索引，不重建
-- 2) 第 2 个 ' 起：开始循环
--    - 命中起点 s：只循环 s 后面的 m-1 个形态（跳过 s 本身）
--    - 未命中：从 all[1] 开始循环 m 个形态
-- 3) 走完一圈：恢复到 baseline_head，并尾部只保留 1 个 '
-- 4) 支持 N=3..8（可扩展 PATTERNS）
-- 5) 使用 update_notifier 预缓存可见分段，避免移动端“晚一拍”

local K_REJECT, K_ACCEPT, K_NOOP = 0, 1, 2
local M = {}

-- ---------- utils ----------
local function escp(ch) return ch:gsub("(%W)","%%%1") end
local function sum(a) local s=0; for _,v in ipairs(a) do s=s+v end; return s end
local function key_of(a) return table.concat(a, ",") end
local function find_idx(list, key) for i,t in ipairs(list) do if key_of(t)==key then return i end end end
local function count_trailing(s, ch) local n=0; for i=#s,1,-1 do if s:sub(i,i)==ch then n=n+1 else break end end; return n end
local function strip_trailing(s, ch) return (s:gsub(escp(ch).."+$","")) end

-- 去掉手动与自动分隔符，得到“纯编码”
local function strip_delims(s, md, ad)
  if md and md~="" then s = s:gsub(escp(md),"") end
  if ad and ad~="" then s = s:gsub(escp(ad),"") end
  return s
end

-- 依据分组把 core 插入手动分隔符重建
local function build_by_groups(core, ch_manual, groups)
  if not groups or #groups==0 or sum(groups)~=#core then return core end
  local out, i = {}, 1
  for gi,g in ipairs(groups) do
    out[#out+1] = core:sub(i, i+g-1); i = i + g
    if gi < #groups then out[#out+1] = ch_manual end
  end
  return table.concat(out)
end

-- 从字符串解析分段长度（空格或 ' 都视为可见分隔）
local function lens_from_string(s, md, ad)
  if not s or s=="" then return nil end
  local segs, buf = {}, {}
  local function flush() if #buf>0 then segs[#segs+1]=table.concat(buf); buf={} end end
  for i=1,#s do
    local c=s:sub(i,i)
    if c==md or c==ad or c==" " then
      flush()
    else
      local b=string.byte(c)
      if b and ((b>=65 and b<=90) or (b>=97 and b<=122)) then
        buf[#buf+1]=string.char(b):lower()
      end
    end
  end
  flush()
  if #segs==0 then return nil end
  local L={}; for _,seg in ipairs(segs) do L[#L+1]=#seg end
  return L
end

-- —— 缓存读取：优先用通知器缓存的 lens，其次现场计算 ——
local function get_cached_lens(env, ctx, md, ad)
  local L = env._last_preedit_lens
  if L and type(L)=="table" and #L>0 then return L end
  local seg = ctx.composition:back()
  local cand = seg and seg:get_selected_candidate() or nil
  return lens_from_string(cand and cand.preedit or nil, md, ad)
end

-- ---------- patterns ----------
local PATTERNS = {
  [3] = { all = { {2,1}, {1,2} } },
  [4] = { all = { {2,2}, {1,3}, {3,1} } },
  [5] = { all = { {2,3}, {3,2} } },
  [6] = { all = { {2,2,2}, {3,3} } },
  [7] = { all = { {2,2,3}, {2,3,2}, {3,2,2} } },
  [8] = { all = { {2,2,2,2}, {2,3,3}, {3,2,3}, {3,3,2} } },
}

-- ---------- session state ----------
local function reset_session(env)
  env._ss_core_letters  = nil  -- 纯编码（去分隔）
  env._ss_start_idx     = nil  -- 起点索引（1..m），未命中则 0
  env._ss_N             = nil
  env._ss_baseline_head = nil  -- 基线：包含你之前的手动分隔/空格
end

function M.init(env)
  local cfg = env.engine.schema.config
  local delimiter = cfg:get_string("speller/delimiter") or " '"
  if #delimiter < 2 then delimiter = " '" end
  env.auto_delim   = delimiter:sub(1,1)  -- 通常空格
  env.manual_delim = delimiter:sub(2,2)  -- 通常单引号

  -- 缓存最新一帧的可见分段与输入
  env._upd_conn = env.engine.context.update_notifier:connect(function(ctx)
    local seg  = ctx.composition:back()
    local cand = seg and seg:get_selected_candidate() or nil
    local pre  = cand and cand.preedit or nil
    env._last_preedit_lens = lens_from_string(pre, env.manual_delim, env.auto_delim)
    env._last_input_head   = ctx.input
  end)

  reset_session(env)
end

function M.fini(env)
  if env._upd_conn then env._upd_conn:disconnect(); env._upd_conn=nil end
end

-- ---------- main ----------
function M.func(key_event, env)
  if key_event:release() then return K_NOOP end

  local ctx = env.engine.context
  if ctx.composition:empty() then return K_NOOP end

  local md = env.manual_delim or "'"
  local ad = env.auto_delim   or " "

  -- 只处理手动分隔符键
  if key_event.keycode ~= string.byte(md) then
    reset_session(env); return K_NOOP
  end

  -- 把这次 ' 并入输入，统计尾部 ' 数
  local before = ctx.input or ""
  local after  = before .. md
  local tlen   = count_trailing(after, md)

  -- 去掉末尾 ' 串，得到 head（本次按键前的完整输入）与 core（纯编码）
  local head  = strip_trailing(after, md)
  local core  = strip_delims(head, md, ad)
  local N     = #core
  local conf  = PATTERNS[N]

  -- 若核心/长度变化，重置会话
  if env._ss_core_letters ~= core or env._ss_N ~= N then
    env._ss_core_letters  = core
    env._ss_N             = N
    env._ss_start_idx     = nil
    env._ss_baseline_head = nil
  end

  -- 只要本轮还没记过，就立刻记录“基线 + 起点”（无论 tlen==1 还是 tlen>=2）
  if env._ss_baseline_head == nil then
    env._ss_baseline_head = head   -- 保留你原有的空格或手动 '
  end
  if conf and env._ss_start_idx == nil then
    local start_idx = 0
    -- 先用缓存的可见分段；不行就直接用 head 切分（可避免“23 又走到 23'”的伪步骤）
    local L = get_cached_lens(env, ctx, md, ad)
    if not (L and sum(L)==N) then
      L = lens_from_string(head, md, ad)
    end
    if L and sum(L)==N then
      local idx = find_idx(conf.all, key_of(L))
      if idx then start_idx = idx end
    end
    env._ss_start_idx = start_idx
  end

  -- 第 1 个 ' ：仅记录，不重建
  if tlen == 1 then
    ctx.input = after
    return K_ACCEPT
  end

  -- 第 2 个 ' 起：循环（若无该长度配置，直接接纳输入）
  if not conf then
    ctx.input = after
    return K_ACCEPT
  end

  local m = #conf.all
  local k = tlen - 1  -- 从第二个 ' 开始计数

  -- 恢复：回到第一拍记录的 baseline（保留空格/已有 '），尾部只留 1 个 '
  local function restore()
    local baseline = env._ss_baseline_head or head
    ctx.input = baseline .. md
    reset_session(env)
    env._ss_core_letters = core
    env._ss_N = N
  end

  if env._ss_start_idx and env._ss_start_idx ~= 0 then
    -- 命中起点：只循环后续 m-1 个形态，跳过当前形态
    local variants_count = m - 1
    local cycle_len = variants_count + 1
    local r = k % cycle_len
    if r == 0 then
      restore(); return K_ACCEPT
    else
      local idx = ((env._ss_start_idx - 1 + r) % m) + 1  -- 跳过起点本身
      local groups = conf.all[idx]
      local rebuilt = build_by_groups(core, md, groups)
      ctx.input = rebuilt .. md:rep(tlen)
      return K_ACCEPT
    end
  else
    -- 未命中起点：从 all[1] 开始循环 m 个形态
    local variants_count = m
    local cycle_len = variants_count + 1
    local r = k % cycle_len
    if r == 0 then
      restore(); return K_ACCEPT
    else
      local idx = ((r - 1) % m) + 1
      local groups = conf.all[idx]
      local rebuilt = build_by_groups(core, md, groups)
      ctx.input = rebuilt .. md:rep(tlen)
      return K_ACCEPT
    end
  end
end

return { init = M.init, fini = M.fini, func = M.func }
