-- librime-lua 官方类型提示
-- ⚠️ 仅用于类型提升，请勿直接 require 使用
-- from https://github.com/hchunhui/librime-lua/blob/master/contrib/librime.lua
-- Copyright (c) 2021, librime-lua Developers
-- This software is licensed under the BSD-3-Clause license.
-- Last Change: 2026-08-31

---@meta rime

--- 全局对象

---@class RimeAPI
---@field get_rime_version fun(): string
---@field get_shared_data_dir fun(): string
---@field get_user_data_dir fun(): string
---@field get_sync_dir fun(): string
---@field get_distribution_name fun(): string
---@field get_distribution_code_name fun(): string
---@field get_distribution_version fun(): string
---@field get_user_id fun(): string
--- 获取毫秒级时间值，适合双击判断、超时、输入间隔和性能统计。
--- 兼容旧版插件时可先判断：rime_api and rime_api.get_time_ms and rime_api.get_time_ms() or os.time() * 1000
---@field get_time_ms fun(): number
--- 使用 librime 的正则实现判断输入；
---@field regex_match fun(input: string, pattern: string): boolean
---@field regex_search fun(input: string, pattern: string): string[] | nil
---@field regex_replace fun(input: string, pattern: string, fmt: string): string
rime_api = {}

---@class Log
---@field info fun(string)
---@field warning fun(string)
---@field error fun(string)
log = {}

---@param cand Candidate
function yield(cand) end

--- 常量

---@enum ConfigType
local config_types = {
  kNull = "kNull",
  kScalar = "kScalar",
  kList = "kList",
  kMap = "kMap",
}

---@enum SegmentType
local segment_types = {
  kVoid = "kVoid",
  kGuess = "kGuess",
  kSelected = "kSelected",
  kConfirmed = "kConfirmed",
}

---@enum CandidateDynamicType
local candidate_dynamic_types = {
  kSentence = "Sentence",
  kPhrase = "Phrase",
  kSimple = "Simple",
  kShadow = "Shadow",
  kUniquified = "Uniquified",
  kOther = "Other",
}

---@enum ProcessResult
local process_results = {
  kRejected = 0,
  kAccepted = 1,
  kNoop = 2,
}

---@enum ModifierMask
local modifier_masks = {
  kShift = 0x1,
  kLock = 0x2,
  kControl = 0x4,
  kAlt = 0x8,
}

--- 工具

---@class Set
---@field empty fun(self: self): boolean
---@field __index function
---@field __add function
---@field __sub function
---@field __mul function
---@field __set function

---@param values any[]
---@return Set
function Set(values) end

--- 对象接口及构造函数

---@class Env
---@field engine Engine
---@field name_space string

---@class Engine
---@field schema Schema
---@field context Context
---@field active_engine Engine
--- 将一个 KeyEvent 重新送入引擎；返回是否被处理器接受。
---@field process_key fun(self: self, key_event: KeyEvent): boolean
---@field compose fun(self: self, ctx: Context)
---@field commit_text fun(self: self, text: string)
---@field apply_schema fun(self: self, schema: Schema)

---@class Context
---@field composition Composition
--- 当前原始输入。caret_pos、Segment 起止位置均以该字符串的位置计。
---@field input string
---@field caret_pos integer
---@field commit_notifier Notifier
---@field select_notifier Notifier
---@field update_notifier Notifier
---@field delete_notifier Notifier
---@field option_update_notifier OptionUpdateNotifier
---@field property_update_notifier PropertyUpdateNotifier
---@field unhandled_key_notifier KeyEventNotifier
---@field commit_history CommitHistory
---@field commit fun(self: self)
---@field get_commit_text fun(self: self): string
---@field get_script_text fun(self: self): string
---@field get_preedit fun(self: self): Preedit
---@field is_composing fun(self: self): boolean
---@field has_menu fun(self: self): boolean
--- 无可选候选时可能返回 nil。
---@field get_selected_candidate fun(self: self): Candidate|nil
---@field push_input fun(self: self, text: string)
---@field pop_input fun(self: self, len: integer): boolean
---@field delete_input fun(self: self, len: integer): boolean
---@field clear fun(self: self)
--- 选中并确认当前段候选；候选下标从 0 开始。
---@field select fun(self: self, index: integer): boolean
--- 只移动高亮，不确认候选；候选下标从 0 开始。
--- option 切换导致候选重算时，可先保存 Segment.selected_index，再 refresh 后用 highlight 恢复。
---@field highlight fun(self: self, index: integer): boolean
---@field confirm_current_selection fun(self: self): boolean
---@field delete_current_selection fun(self: self): boolean
---@field confirm_previous_selection fun(self: self): boolean
---@field reopen_previous_selection fun(self: self): boolean
---@field clear_previous_segment fun(self: self): boolean
---@field reopen_previous_segment fun(self: self): boolean
--- 清除当前未确认部分，已确认段保留。
---@field clear_non_confirmed_composition fun(self: self): boolean
--- 重新翻译当前未确认部分，用于 option、外部状态或候选来源发生变化后刷新候选。
---@field refresh_non_confirmed_composition fun(self: self): boolean
--- 修改 option；引擎在正在组词时会触发未确认候选刷新。
---@field set_option fun(self: self, name: string, value: boolean)
---@field get_option fun(self: self, name: string): boolean
---@field set_property fun(self: self, key: string, value: string)
---@field get_property fun(self: self, key: string): string
---@field clear_transient_options fun(self: self)
--- 注意：Context 没有 get_candidate(index) 接口。
--- 按下标取候选应使用 context.composition:back():get_candidate_at(index)
--- 或 segment.menu:get_candidate_at(index)。

---@class Preedit
---@field text string
---@field caret_pos integer
---@field sel_start integer
---@field sel_end integer

---@class Composition
---@field empty fun(self: self): boolean
--- 空 composition 返回 nil。
---@field back fun(self: self): Segment|nil
---@field pop_back fun(self: self)
---@field push_back fun(self: self, segment: Segment)
---@field has_finished_composition fun(self: self): boolean
---@field get_prompt fun(self: self): string
---@field toSegmentation fun(self: self): Segmentation
---@field spans fun(self: self): Spans

---@class Segmentation
---@field input string
---@field size integer
---@field empty fun(self: self): boolean
---@field back fun(self: self): Segment | nil
---@field pop_back fun(self: self)
---@field reset_length fun(self: self, length: integer)
---@field add_segment fun(self: self, seg: Segment): boolean
---@field forward fun(self: self): boolean
---@field trim fun(self: self): boolean
---@field has_finished_segmentation fun(self: self): boolean
---@field get_current_start_position fun(self: self): integer
---@field get_current_end_position fun(self: self): integer
---@field get_current_segment_length fun(self: self): integer
---@field get_confirmed_position fun(self: self): integer
---@field get_segments fun(self: self): Segment[]
--- 获取指定 Segment：非负下标从 0 开始，也支持 -1 表示最后一段；越界返回 nil。
---@field get_at fun(self: self, index: integer): Segment|nil

---@class Segment
---@field status SegmentType
--- start/_start 与 _end 是原始输入中的区间位置，_end 为区间末端。
---@field start integer
---@field _start integer
---@field _end integer
---@field length integer
---@field tags Set
--- 当前段没有候选菜单时可能为 nil。
---@field menu Menu|nil
--- 当前高亮候选下标，从 0 开始。
---@field selected_index integer
---@field prompt string
---@field clear fun(self: self)
---@field close fun(self: self)
---@field reopen fun(self: self, caret_pos: integer)
---@field has_tag fun(self: self, tag: string): boolean
--- 按 0 起始下标获取候选；越界返回 nil。
---@field get_candidate_at fun(self: self, index: integer): Candidate|nil
---@field get_selected_candidate fun(self: self): Candidate|nil
---@field active_text fun(self: self, text: string): string
--- 返回该段用于物理切分的 spans
---@field spans fun(self: self): Spans

---@param start_pos integer
---@param end_pos integer
---@return Segment
function Segment(start_pos, end_pos) end

---@class Spans
---@field _start integer
---@field _end integer
--- 当前绑定通常将 count、vertices 暴露为属性；兼容旧环境时可用 type(...) 判断是否为函数。
---@field count integer
--- 切分顶点位置；用于按原始 input 的位置恢复物理音节边界。
---@field vertices integer[]
---@field add_span fun(self: self, start: integer, end: integer)
---@field add_spans fun(self: self, spans: Spans)
---@field add_vertex fun(self: self, vertex: integer)
---@field previous_stop fun(self: self, caret_pos: integer): integer
---@field next_stop fun(self: self, caret_pos: integer): integer
---@field has_vertex fun(self: self, vertex: integer): boolean
---@field count_between fun(self: self, start: integer, end: integer): integer
---@field clear fun(self: self)

---@return Spans
function Spans() end

---@class Schema
---@field schema_id string
---@field schema_name string
---@field config Config
---@field page_size integer
---@field select_keys string

---@param schema_id string
---@return Schema
function Schema(schema_id) end

---@class Config
---@field load_from_file fun(self: self, filename: string): boolean
---@field save_to_file fun(self: self, filename: string): boolean
---@field is_null fun(self: self, conf_path: string): boolean
---@field is_value fun(self: self, conf_path: string): boolean
---@field is_list fun(self: self, conf_path: string): boolean
---@field is_map fun(self: self, conf_path: string): boolean
---@field get_bool fun(self: self, conf_path: string): boolean|nil
---@field set_bool fun(self: self, conf_path: string, b: boolean): boolean
---@field get_int fun(self: self, conf_path: string): integer|nil
---@field set_int fun(self: self, conf_path: string, i: integer): boolean
---@field get_double fun(self: self, conf_path: string): number|nil
---@field set_double fun(self: self, conf_path: string, f: number): boolean
---@field get_string fun(self: self, conf_path: string): string|nil
---@field set_string fun(self: self, conf_path: string, s: string): boolean
---@field get_item fun(self: self, conf_path: string): ConfigItem|nil
---@field set_item fun(self: self, conf_path: string, item: ConfigItem): boolean
---@field get_value fun(self: self, conf_path: string): ConfigValue|nil
---@field set_value fun(self: self, conf_path: string, value: ConfigValue): boolean
---@field get_list fun(self: self, conf_path: string): ConfigList|nil
---@field set_list fun(self: self, conf_path: string, list: ConfigList): boolean
---@field get_map fun(self: self, conf_path: string): ConfigMap|nil
---@field set_map fun(self: self, conf_path: string, map: ConfigMap): boolean
---@field get_list_size fun(self: self, conf_path: string): integer|nil

---@class ConfigMap
---@field type ConfigType
---@field size integer
---@field element ConfigItem
---@field empty fun(self: self): boolean
---@field has_key fun(self: self, key: string): boolean
---@field keys fun(self: self): string[]
---@field get fun(self: self, key: string): ConfigItem|nil
---@field get_value fun(self: self, key: string): ConfigValue|nil
---@field set fun(self: self, key: string, item: ConfigItem)
---@field clear fun(self: self)

---@return ConfigMap
function ConfigMap() end

---@class ConfigList
---@field type ConfigType
---@field size integer
---@field element ConfigItem
--- ConfigList 下标从 0 开始。
---@field get_at fun(self: self, index: integer): ConfigItem|nil
---@field get_value_at fun(self: self, index: integer): ConfigValue|nil
---@field set_at fun(self: self, index: integer, item: ConfigItem): boolean
---@field append fun(self: self, item: ConfigItem): boolean
---@field insert fun(self: self, i: integer, item: ConfigItem): boolean
---@field clear fun(self: self): boolean
---@field empty fun(self: self): boolean
---@field resize fun(self: self, size: integer): boolean

---@return ConfigList
function ConfigList() end

---@class ConfigValue
---@field type ConfigType
---@field value string
---@field element ConfigItem
---@field get_bool fun(self: self): boolean|nil
---@field get_int fun(self: self): integer|nil
---@field get_double fun(self: self): number|nil
---@field get_string fun(self: self): string|nil
---@field set_bool fun(self: self, b: boolean)
---@field set_int fun(self: self, i: integer)
---@field set_double fun(self: self, f: number)
---@field set_string fun(self: self, s: string)

---@param value string | boolean
---@return ConfigValue
function ConfigValue(value) end

---@class ConfigItem
---@field type ConfigType
---@field empty boolean
---@field get_value fun(self: self): ConfigValue|nil
---@field get_map fun(self: self): ConfigMap|nil
---@field get_list fun(self: self): ConfigList|nil
---@field get_obj fun(self: self): ConfigMap|ConfigList|ConfigValue|nil

---@class KeyEvent
---@field keycode integer
---@field modifier integer
---@field shift fun(self: self): boolean
---@field ctrl fun(self: self): boolean
---@field alt fun(self: self): boolean
---@field caps fun(self: self): boolean
---@field super fun(self: self): boolean
---@field release fun(self: self): boolean
---@field repr fun(self: self): string
---@field eq fun(self: self, key: KeyEvent): boolean
---@field lt fun(self: self, key: KeyEvent): boolean

---@param repr string
---@return KeyEvent
function KeyEvent(repr) end

---@param keycode integer
---@param modifier integer
---@return KeyEvent
function KeyEvent(keycode, modifier) end

---@class KeySequence
---@field parse fun(self: self, repr: string): boolean
---@field repr fun(self: self): string
---@field toKeyEvent fun(self: self): KeyEvent[]

---@param repr string?
---@return KeySequence
function KeySequence(repr) end

---@class Candidate
---@field type string
--- 候选覆盖的原始输入区间；start/_start 起点，_end 终点。
---@field start integer
---@field _start integer
---@field _end integer
---@field quality number
---@field text string
---@field comment string
---@field preedit string
---@field get_dynamic_type fun(self: self): CandidateDynamicType
---@field get_genuine fun(self: self): Candidate
---@field get_genuines fun(self: self): Candidate[]
---@field to_shadow_candidate fun(self: self, type: string?, text: string?, comment: string?, inherit_comment: boolean?): ShadowCandidate
---@field to_uniquified_candidate fun(self: self, type: string?, text: string?, comment: string?): UniquifiedCandidate
---@field to_phrase fun(self: self): Phrase
---@field to_sentence fun(self: self): Sentence
---@field append fun(self: self, cand: Candidate)
---@field spans fun(self: self): Spans

---@param type string
---@param start integer
---@param _end integer
---@param text string
---@param comment string
---@return Candidate
function Candidate(type, start, _end, text, comment) end

---@class UniquifiedCandidate: Candidate

---@param candidate Candidate
---@param type string?
---@param text string?
---@param comment string?
function UniquifiedCandidate(candidate, type, text, comment) end

---@class ShadowCandidate: Candidate

---@param candidate Candidate
---@param type string?
---@param text string?
---@param comment string?
---@param inherit_comment boolean?
---@return ShadowCandidate
function ShadowCandidate(candidate, type, text, comment, inherit_comment) end

---@class Phrase
-----@field language Language 暂时不支持
---@field lang_name string
---@field type string
---@field start integer
---@field _start integer
---@field _end integer
---@field quality number
---@field text string
---@field comment string
---@field preedit string
---@field weight number
---@field code Code
---@field entry DictEntry
---@field toCandidate fun(self: self): Candidate
---@field spans fun(self: self): Spans

---@param memory Memory
---@param type string
---@param start integer
---@param _end integer
---@param entry DictEntry
---@return Phrase
function Phrase(memory, type, start, _end, entry) end

---@class Sentence
-----@field language Language 暂时不支持
---@field lang_name string
---@field type string
---@field start integer
---@field _start integer
---@field _end integer
---@field quality number
---@field text string
---@field comment string
---@field preedit string
---@field weight number
---@field code Code
---@field entry DictEntry
---@field word_lengths integer[]
---@field entrys DictEntry[]
---@field entrys_size integer
---@field entrys_empty boolean
---@field toCandidate fun(self: self): Candidate

---@class Menu
---@field add_translation fun(self: self, translation: Translation)
--- 预取至少 candidate_count 个候选，并返回实际准备数量。
---@field prepare fun(self: self, candidate_count: integer): integer
--- 候选下标从 0 开始；越界返回 nil。
---@field get_candidate_at fun(self: self, i: integer): Candidate|nil
---@field candidate_count fun(self: self): integer
---@field empty fun(self: self): boolean

---@return Menu
function Menu() end

---@class Opencc
---@field convert fun(self: self, text: string): string
---@field convert_text fun(self: self, text: string): string
---@field random_convert_text fun(self: self, text: string): string
---@field convert_word fun(self: self, text: string): string[]

---@param filename string
---@return Opencc
function Opencc(filename) end

---@class Dictionary
---@field name string
---@field loaded boolean
---@field lookup_words fun(self: self, code: string, predictive: boolean, limit: integer): boolean
---@field decode fun(self: self, code: Code): string[]

---@class DictEntryIterator
---@field exhausted boolean
---@field size integer
---@field iter fun(self: self): fun(): DictEntry|nil

---@class UserDictionary
---@field name string
---@field loaded boolean
---@field tick integer
---@field lookup_words fun(self: self, code: string, predictive: boolean, limit: integer): boolean
---@field update_entry fun(self: self, entry: DictEntry, commits: integer, prefix: string, lang_name: string): boolean

---@class UserDictEntryIterator
---@field exhausted boolean
---@field size integer
---@field iter fun(self: self): fun(): DictEntry|nil

--- 直接读取 .reverse.bin 数据文件；参数是文件路径/文件名。
---@class ReverseDb
---@field lookup fun(self: self, key: string): string

---@param file_name string
---@return ReverseDb
function ReverseDb(file_name) end

--- 按 Rime 词典名称建立反查；参数是 dictionary 名称，不是 .reverse.bin 路径。
---@class ReverseLookup
---@field lookup fun(self: self, key: string): string
---@field lookup_stems fun(self: self, key: string): string

---@param dict_name string
---@return ReverseLookup
function ReverseLookup(dict_name) end

---@class DictEntry
---@field text string
---@field comment string
---@field preedit string
---@field weight number
---@field commit_count integer `2`
---@field custom_code string "hao", "ni hao"
---@field remaining_code_length integer "~ao"
---@field code Code

---@return DictEntry
function DictEntry() end

---@class CommitEntry: DictEntry
---@field get fun(self: self): DictEntry[]
---@field update_entry fun(self: self, entry: DictEntry, commit: integer, prefix: string): boolean
---@field update fun(self: self, commit: integer): boolean

---@class Code
---@field push fun(self: self, syllable_id: integer)
---@field print fun(self: self): string

---@return Code
function Code() end

---@alias TranslationIterator fun(state: Translation): Candidate|nil

---@class Translation
---@field exhausted boolean
--- 返回 iterator 与当前 Translation 状态。
--- 可直接 `for cand in translation:iter() do ... end`，
--- 也可 `local next_cand, state = translation:iter()` 后手动逐个读取。
---@field iter fun(self: self): TranslationIterator, Translation

function Translation() end

--- 访问词典/用户词典的运行时对象；长期持有时应在 fini 中 disconnect()。
---@class Memory
---@field lang_name string
---@field dict Dictionary
---@field user_dict UserDictionary
---@field start_session fun(self: self): boolean
---@field finish_session fun(self: self): boolean
---@field discard_session fun(self: self): boolean
---@field dict_lookup fun(self: self, input: string, predictive: boolean, limit: integer): boolean
---@field user_lookup fun(self: self, input: string, predictive: boolean): boolean
---@field dictiter_lookup fun(self: self, input: string, predictive: boolean, limit: integer): DictEntryIterator
---@field useriter_lookup fun(self: self, input: string, predictive: boolean): UserDictEntryIterator
---@field memorize fun(self: self, callback: fun(ce: CommitEntry))
---@field decode fun(self: self, code: Code): string[]
---@field iter_dict fun(self: self): fun(): DictEntry|nil
---@field iter_user fun(self: self): fun(): DictEntry|nil
---@field update_userdict fun(self: self, entry: DictEntry, commits: integer, prefix: string): boolean
---@field update_entry fun(self: self, entry: DictEntry, commits: integer, prefix: string, lang_name?: string): boolean
---@field update_candidate fun(self: self, candidate: Candidate, commits: integer): boolean
---@field disconnect fun(self: self)

---@param engine Engine
---@param schema Schema
---@param namespace string?
---@return Memory
function Memory(engine, schema, namespace) end

---@class Projection
---@field load fun(self: self, rules: ConfigList): boolean
---@field apply fun(self: self, str: string, ret_org_str?: boolean): string

---@return Projection
function Projection() end

--- 动态创建 Rime 原生组件。namespace 对应 schema 配置节点，klass 为组件类型名。
---@class Component
---@field Processor fun(engine: Engine, namespace: string, klass: string): Processor
---@field Translator fun(engine: Engine, namespace: string, klass: string): Translator
---@field Segmentor fun(engine: Engine, namespace: string, klass: string): Segmentor
---@field Filter fun(engine: Engine, namespace: string, klass: string): Filter
---@field ScriptTranslator fun(engine: Engine, namespace: string, klass: string): ScriptTranslator
---@field TableTranslator fun(engine: Engine, namespace: string, klass: string): TableTranslator
Component = {}

---@class Processor
---@field name_space string
---@field process_key_event fun(self: self, key_event: KeyEvent): ProcessResult

---@class Segmentor
---@field name_space string
---@field proceed fun(self: self, segmentation: Segmentation): boolean

---@class Translator
---@field name_space string
---@field query fun(self: self, input: string, segment: Segment): Translation|nil

---@class ScriptTranslator
---@field name_space string
---@field lang_name string
---@field memorize_callback fun(ce: CommitEntry)
---@field max_homophones integer
---@field spelling_hints integer
---@field always_show_comments boolean
---@field enable_correction boolean
---@field delimiters string
---@field tag string
---@field enable_completion boolean
---@field contextual_suggestions boolean
---@field strict_spelling boolean
---@field initial_quality number
---@field preedit_formatter Projection
---@field comment_formatter Projection
---@field dict Dictionary
---@field user_dict UserDictionary
---@field translator Translator
---@field query fun(self: self, input: string, segment: Segment): Translation|nil
---@field start_session fun(self: self): boolean
---@field finish_session fun(self: self): boolean
---@field discard_session fun(self: self): boolean
---@field memorize fun(self: self, callback: fun(ce: CommitEntry))
---@field update_entry fun(self: self, entry: DictEntry, commits: integer, prefix: string): boolean
---@field reload_user_dict_disabling_patterns fun(self: self, config_list: ConfigList): boolean
---@field set_memorize_callback fun(self: self, callback: fun(ce: CommitEntry))
---@field disconnect fun(self: self)

---@class TableTranslator
---@field name_space string
---@field lang_name string
---@field memorize_callback fun(ce: CommitEntry)
---@field enable_charset_filter boolean
---@field enable_encoder boolean
---@field enable_sentence boolean
---@field sentence_over_completion boolean
---@field encode_commit_history boolean
---@field max_phrase_length integer
---@field max_homographs integer
---@field delimiters string
---@field tag string
---@field enable_completion boolean
---@field contextual_suggestions boolean
---@field strict_spelling boolean
---@field initial_quality number
---@field preedit_formatter Projection
---@field comment_formatter Projection
---@field dict Dictionary
---@field user_dict UserDictionary
---@field translator Translator
---@field query fun(self: self, input: string, segment: Segment): Translation|nil
---@field start_session fun(self: self): boolean
---@field finish_session fun(self: self): boolean
---@field discard_session fun(self: self): boolean
---@field memorize fun(self: self, callback: fun(ce: CommitEntry))
---@field update_entry fun(self: self, entry: DictEntry, commits: integer, prefix: string): boolean
---@field reload_user_dict_disabling_patterns fun(self: self, config_list: ConfigList): boolean
---@field set_memorize_callback fun(self: self, callback: fun(ce: CommitEntry))
---@field disconnect fun(self: self)

---@class Filter
---@field name_space string
---@field apply fun(self: self, translation: Translation): Translation

--- connect() 返回 Connection；组件持有连接时应在 fini/release 中 disconnect()。
---@class Notifier
---@field connect fun(self: self, f: fun(ctx: Context), group: integer|nil): Connection

---@class OptionUpdateNotifier: Notifier
---@field connect fun(self: self, f: fun(ctx: Context, name: string), group: integer|nil): Connection

---@class PropertyUpdateNotifier: Notifier
---@field connect fun(self: self, f: fun(ctx: Context, name: string), group: integer|nil): Connection

---@class KeyEventNotifier: Notifier
---@field connect fun(self: self, f: fun(ctx: Context, key: KeyEvent), group: integer|nil): Connection

---@class Connection
---@field disconnect fun(self: self)

---@class Switcher
---@field attached_engine Engine
---@field user_config Config
---@field active boolean
---@field process_key fun(self: self, key_event: KeyEvent): boolean
---@field select_next_schema fun(self: self)
---@field is_auto_save fun(self: self, option: string): boolean
---@field refresh_menu fun(self: self)
---@field activate fun(self: self)
---@field deactivate fun(self: self)

---@param engine Engine
---@return Switcher
function Switcher(engine) end

---@class CommitRecord
---@field text string
---@field type string

---@class CommitHistory
---@field size integer
---@field push fun(self: self, key_event: KeyEvent)
---@field back fun(self: self): CommitRecord|nil
---@field to_table fun(self: self): CommitRecord[]
---@field iter fun(self: self): fun(): (number, CommitRecord)|nil
---@field latest_text fun(self: self): string
---@field empty fun(self: self): boolean
---@field clear fun(self: self)
---@field pop_back fun(self: self)

---@class DbAccessor
---@field reset fun(self: self): boolean
---@field jump fun(self: self, prefix: string): boolean
--- 遍历 query() 结果，迭代返回 key, value。
---@field iter fun(self: self): fun(): (string, string) | nil

--- UserDb/LevelDb 使用前应确认 loaded()，未加载时调用 open()；不用时可 close()。
---@class UserDb
---@field _loaded boolean
---@field read_only boolean
---@field disabled boolean
---@field name string
---@field file_name string
---@field open fun(self: self): boolean
---@field open_read_only fun(self: self): boolean
---@field close fun(self: self): boolean
---@field query fun(self: self, prefix: string): DbAccessor
---@field fetch fun(self: self, key: string): string|nil
---@field update fun(self: self, key: string, value: string): boolean
---@field erase fun(self: self, key: string): boolean
---@field loaded fun(self: self): boolean
---@field disable fun(self: self): boolean
---@field enable fun(self: self): boolean

---@param db_name string
---@param db_class string
---@return UserDb
function UserDb(db_name, db_class) end

---@class LevelDb: UserDb

---@param db_name string
---@return LevelDb
function LevelDb(db_name) end

---@class TableDb: UserDb

---@param db_name string
---@return TableDb
function TableDb(db_name) end
