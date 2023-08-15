// ***************************************************************************
// ***************************************************************************
// Copyright (C) 2023 Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module sync_header_align (
  input clk,
  input reset,

  input [65:0] i_data,
  output i_slip,
  input i_slip_done,

  output [63:0] o_data,
  output [1:0] o_header,
  output o_block_sync
);

  assign {o_header,o_data} = i_data;

  // TODO : Add alignment FSM
  localparam STATE_SH_HUNT = 3'b001;
  localparam STATE_SH_SLIP = 3'b010;
  localparam STATE_SH_LOCK = 3'b100;

  localparam BIT_SH_HUNT = 0;
  localparam BIT_SH_SLIP = 1;
  localparam BIT_SH_LOCK = 2;

  localparam RX_THRESH_SH_ERR = 16;
  localparam LOG2_RX_THRESH_SH_ERR = $clog2(RX_THRESH_SH_ERR);

  reg [2:0] state = STATE_SH_HUNT;
  reg [2:0] next_state;

  reg [7:0] header_vcnt = 8'h0;
  reg [LOG2_RX_THRESH_SH_ERR:0] header_icnt = 'h0;

  wire valid_header;
  assign valid_header = ^o_header;

  always @(posedge clk) begin
    if (reset | ~valid_header) begin
      header_vcnt <= 'b0;
    end else if (state[BIT_SH_HUNT] & ~header_vcnt[7]) begin
      header_vcnt <= header_vcnt + 'b1;
    end
  end

  always @(posedge clk) begin
    if (reset | valid_header) begin
      header_icnt <= 'b0;
    end else if (state[BIT_SH_LOCK] & ~header_icnt[LOG2_RX_THRESH_SH_ERR]) begin
      header_icnt <= header_icnt + 'b1;
    end
  end

  always @(*) begin
    next_state = state;
    case (state)
      STATE_SH_HUNT:
        if (valid_header) begin
          if (header_vcnt[7]) begin
            next_state = STATE_SH_LOCK;
          end
        end else begin
          next_state = STATE_SH_SLIP;
        end
      STATE_SH_SLIP:
        if (i_slip_done) begin
          next_state = STATE_SH_HUNT;
        end
      STATE_SH_LOCK:
        if (~valid_header) begin
          if (header_icnt[LOG2_RX_THRESH_SH_ERR]) begin
            next_state = STATE_SH_HUNT;
          end
        end
    endcase
  end

  always @(posedge clk) begin
    if (reset == 1'b1) begin
      state <= STATE_SH_HUNT;
    end else begin
      state <= next_state;
    end
  end

  assign o_block_sync = state[BIT_SH_LOCK];
  assign i_slip = state[BIT_SH_SLIP];

endmodule
