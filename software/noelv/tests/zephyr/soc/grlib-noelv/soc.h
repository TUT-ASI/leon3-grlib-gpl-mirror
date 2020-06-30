/*
 * Copyright (c) 2018 - 2019 Antmicro <www.antmicro.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef __RISCV64_GRLIB_NOELV_SOC_H_
#define __RISCV64_GRLIB_NOELV_SOC_H_

#include "../riscv-privilege/common/soc_common.h"
#include <generated_dts_board.h>

/* Hard code SRAM config */
#define DT_SRAM_BASE_ADDRESS        0x40000000
#define DT_SRAM_SIZE                0x10000000

/* lib-c hooks required RAM defined variables */
#define RISCV_RAM_BASE              DT_SRAM_BASE_ADDRESS
#define RISCV_RAM_SIZE              DT_SRAM_SIZE

#define __BSP_CON_HANDLE            0x80000100

#endif /* __RISCV64_GRLIB_NOELV_SOC_H_ */
