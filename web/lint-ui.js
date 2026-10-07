// Presentation only. Codes, severity and item offsets come from MoonBit.
export const lintRules = {
  logical_max_sign: ['逻辑最大值的编码有歧义', '最小值非负时该编码按无符号数读取。核对预期范围；较宽编码可明确正值意图。'],
  physical_max_sign: ['物理最大值的编码有歧义', '核对物理范围及原编码的正负含义；这是编码建议，并非兼容性失败证明。'],
  null_without_room: ['没有为 Null 状态留出取值', '逻辑范围占满当前位宽，范围之外没有值可表示空闲状态。核对范围或位宽。'],
  usage_count: ['Usage 数量与映射范围需核对', 'Variable 按元素匹配 Usage；Array 按逻辑选择值匹配。厂商原始数据块可能有意采用其他约定。'],
  missing_usage: ['数据字段缺少 Usage', '这个数据字段没有优选 Usage。核对前一个 Main 是否已消耗本地 Usage。'],
  unaligned_report: ['报告末尾不足整字节', '传输报告需要补零到完整字节。可用 Constant 字段明确尾部填充。'],
  field_outside_application: ['数据字段位于 Application 之外', '核对集合层级，确保数据字段属于预期的 Application Collection。'],
  collection_without_usage: ['Collection 缺少 Usage', '在 Collection 前声明其对应 Usage；本地 Usage 在每个 Main 后会重置。'],
  multiple_applications_without_report_id: ['多个顶层 Application 未使用报告 ID', '核对同方向报告是否跨集合；方向不同的报告可能只需要关注路由。'],
  report_id_shared_across_applications: ['同方向报告跨多个顶层 Application', '相同方向、相同 ID 的字段属于不同顶层 Application，核对报告归属或分配独立 ID。'],
};

export function lintText(lint) {
  const [title, advice] = lintRules[lint.code] ?? ['其他检查提示', '请结合原始消息与设备协议核对。'];
  return { title, advice, level: lint.level === 'warning' ? '需核对' : lint.level === 'info' ? '建议' : lint.level };
}

export function lintCounts(lints) {
  return { warning: lints.filter(l => l.level === 'warning').length, info: lints.filter(l => l.level === 'info').length };
}
