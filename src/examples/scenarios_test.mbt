///|
test "four application scenarios have stable complete output" {
  inspect(
    @examples.scenario_lines().join("\n"),
    content=(
      #|1. 键盘
      #|生成键盘与 LED 描述符 → 05 01 09 06 a1 01 05 07 19 e0 29 e7 15 00 25 01 75 01 95 08 81 02 75 08 95 01 81 01 19 00 29 65 15 00 25 65 75 08 95 06 81 00 05 08 19 01 29 05 15 00 25 01 75 01 95 05 91 02 75 03 95 01 91 01 c0
      #|按下 Left Shift + A → 02 00 04 00 00 00 00 00
      #|释放 Left Shift + A → 00 00 00 00 00 00 00 00
      #|解码 LED Output 03 → Num Lock = 1, Caps Lock = 1
      #|2. 鼠标和手柄
      #|解码鼠标 05 ff 02 fe → X = -1, Y = 2, Wheel = -2
      #|Button 2 置 1，保留其他位 → 05 ff 02 fe → 07 ff 02 fe
      #|初始化 Hat Null（ID 9）→ 09 0f
      #|Hat 设为 90 度并读回 → 逻辑值 2, 角度 90 度, 完整报告 09 02
      #|3. 媒体键和厂商配置
      #|编码 Play/Pause（Usage 0x0c:0xcd）→ cd 00
      #|33 位 Raw Feature（宽松扩展，非 HID 1.11 标准证据）→ 07 f8 ff ff ff 0f
      #|读取厂商配置 Raw → ff ff ff ff 01
      #|写入并读回厂商配置 → 07 90 a0 b1 c2 0b, Raw = 12 34 56 78 01
      #|4. 固件回归
      #|检查没有空闲值的 Hat → null_without_room
      #|报告少一个字节 → report_length
      #|鼠标 X 写入 -128（Logical -127..127）→ logical_range
      #|鼠标解码后重新编码 → 05 ff 02 fe, 字节相同 = true
      #|文件与固定预期回归 → node scripts/firmware-ci.mjs
    ),
  )
}
