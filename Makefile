VERILOG_SRCS :=                   \
core/rtl/nb64_pkg.sv              \
core/rtl/core.sv                  \
core/rtl/rf/nb64__rf_gpr.sv       \
core/rtl/rf/nb64__rf_csr.sv       \
core/rtl/sys/nb64__sys_bootmgr.sv \
core/rtl/sys/nb64__sys_xip.sv     \
core/rtl/mem/nb64__mem_itcm.sv    \
core/rtl/mem/nb64__mem_dtcm.sv    \
core/rtl/ctrl/nb64__ctrl_fwd.sv   \
core/rtl/ctrl/nb64__ctrl_hzd.sv   \
core/rtl/ifu/nb64__ifu_bpred.sv   \
core/rtl/ifu/nb64__ifu_btb.sv     \
core/rtl/ifu/nb64__ifu_ras.sv     \
core/rtl/ifu/nb64__ifu_fetch.sv   \
core/rtl/ifu/nb64__ifu_decode.sv  \
core/rtl/ifu/nb64__ifu.sv         \
core/rtl/exu/nb64__exu_ksa.sv    \
core/rtl/exu/nb64__exu_alu.sv     \
core/rtl/exu/nb64__exu_mul.sv     \
core/rtl/exu/nb64__exu_div.sv     \
core/rtl/exu/nb64__exu_mext.sv    \
core/rtl/exu/nb64__exu_bu.sv      \
core/rtl/exu/nb64__exu.sv         \
core/rtl/lsu/nb64__lsu_align.sv   \
core/rtl/lsu/nb64__lsu.sv

TOP       ?= nb64__core
VERILATOR ?= verilator

.PHONY: lint

lint:
	$(VERILATOR) --sv --lint-only --top-module $(TOP) $(VERILOG_SRCS)
