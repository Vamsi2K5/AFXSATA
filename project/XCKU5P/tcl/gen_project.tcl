# ======================================================
# Vivado Project Create Script (Clean & Structured)
# ======================================================

# 工程信息
set proj_name "sata-fpga"
set proj_dir "../${proj_name}"
set part_name "xcku5p-ffvb676-1-i"
set top_module "sata_example"

# =============================================
# IP 列表，表格形式
# 每个元素格式：{源路径 目标子目录 xci文件名}
# =============================================
set ip_list {
    {../../../ip/ugty_sata         gth_sata          gth_sata.xci}
    {../ip/vio_sata_example        vio_sata_example  vio_sata_example.xci}
}


# 创建新工程（如已存在则覆盖）
if { [file exists $proj_dir] } {
    puts "==> Removing existing project directory..."
    file delete -force $proj_dir
}
create_project $proj_name $proj_dir -part $part_name
puts "==> Project created: $proj_name"

# 添加源文件
add_files ../../../design/incl/sata_wrapper_define.svh
add_files ../../../design/rtl
add_files ../top
add_files ../incl

# 设置全局 include
set_property is_global_include true [get_files ../../../design/incl/sata_wrapper_define.svh]
set_property is_global_include true [get_files ../incl/afx_top_define.svh]

# 添加约束文件
add_files -fileset constrs_1 -norecurse ../constrs/io.xdc

# 创建工程内 ip 目录
if {![file exists "$proj_dir/vivado/source/ip"]} {
    file mkdir "$proj_dir/vivado/source/ip"
    puts "==> Created directory: $proj_dir/vivado/source/ip"
}

# 循环处理 IP
foreach ip_info $ip_list {
    lassign $ip_info src_dir dst_dir xci_file

    # 拷贝 IP 到工程目录
    file copy -force $src_dir $proj_dir/vivado/source/ip/$dst_dir

    # 添加到工程
    add_files -norecurse $proj_dir/vivado/source/ip/$dst_dir/$xci_file

    # 生成 IP 所有目标
    # generate_target all [get_files $proj_dir/vivado/source/ip/$dst_dir/$xci_file]

    # 导出用户文件
    export_ip_user_files -of_objects [get_files $proj_dir/vivado/source/ip/$dst_dir/$xci_file] -force -quiet
}

puts "==> All IP added and exported."

# 设置顶层模块
set_property top $top_module [current_fileset]

# 更新编译顺序
update_compile_order -fileset sources_1

puts "==> Project setup complete."

