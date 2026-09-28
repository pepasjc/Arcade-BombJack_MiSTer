//============================================================================
//  Arcade: Bomb Jack
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;

assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign AUDIO_MIX = 0;
assign FB_FORCE_BLANK = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign VGA_F1    = 0;
assign VGA_SCALER= 0;

wire [1:0] ar = status[22:21];

assign VIDEO_ARX = (!ar) ? ((status[2])  ? 12'd2560 : 12'd2191) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2])  ? 12'd2191 : 12'd2560) : 12'd0;

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X XXXXXXXXXXXXXXXXXX XXX XXXXXXX XXXX

`include "build_id.v" 
localparam CONF_STR = {
	"RA_BMBJCK;;",
	"H0OLM,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"ON,Flip Screen,Off,On;",
	"O[6],Game Speed,Native,60Hz;",
	"O[31:28],CRT H adjust,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"O[35:32],CRT V adjust,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"-;",
	"P1,DIP Switches;",
	"P1O7,Demo Sounds,On,Off;",
	"P1O89,Lives,3,4,5,2;",
	"P1OAB,Bonus,500k,750k;",
	"P1OC,Cabinet,Upright,Cocktail;",
	"P1ODE,Enemy num & speed,Easy,Medium,Hard,Insane;",
	"P1OIJ,Bird Speed,Easy,Medium,Hard,Insane;",
	"P1OFH,Bonus Life,None,Every 100k,Every 30k,50k only,100k only,50k and 100k,100k and 300k,50k and 100k and 300k;",
	"-;",
	"H1OR,Autosave Hiscores,Off,On;",
	"P2,Pause options;",
	"P2OP,Pause when OSD is open,On,Off;",
	"P2OQ,Dim video after 10s,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Jump,Start 1P,Start 2P,Coin,Pause;",
	"jn,A,Start,Select,R,L;",
	"V,v",`BUILD_DATE
};


////////////////////   CLOCKS   ///////////////////

wire clk_sys;
wire pll_locked;
wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys), // 48
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.locked(pll_locked)
);

wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

//Reconfigure PLL to apply an overclock to bring video timings in spec for 60Hz VSync
pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

always @(posedge CLK_50M) begin
	reg overclock = 0, overclock2 = 0;
	reg [2:0] state = 0;
	reg overclock_r;

	overclock <= status[6];
	overclock2 <= overclock;

	cfg_write <= 0;
	if(overclock2 == overclock && overclock2 != overclock_r) begin
		state <= 1;
		overclock_r <= overclock2;
	end

	if(!cfg_waitrequest) begin
		if(state)
			state <= state + 1'd1;
		case(state)
			1: begin
				cfg_address <= 0;
				cfg_data <= 0;
				cfg_write <= 1;
			end
			5: begin
				cfg_address <= 7;
				cfg_data <= overclock_r ? 3221912667 : 2748778984;
				cfg_write <= 1;
			end
			7: begin
				cfg_address <= 2;
				cfg_data <= 0;
				cfg_write <= 1;
			end
		endcase
	end
end

///////////////////////////////////////////////////

wire [63:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire  [7:0]	ioctl_index;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({~hs_configured,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),
	.video_rotated(video_rotated),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);

wire no_rotate = status[2] | direct_video;

wire m_up     = joy[3];
wire m_down   = joy[2];
wire m_left   = joy[1];
wire m_right  = joy[0];
wire m_fire   = joy[4];

wire m_up_2     = joy[3];
wire m_down_2   = joy[2];
wire m_left_2   = joy[1];
wire m_right_2  = joy[0];
wire m_fire_2  = joy[4];

wire m_start1 = joy[5];
wire m_start2 = joy[6];
wire m_coin   = joy[7];
wire m_pause  = joy[8];

// PAUSE SYSTEM
wire pause_cpu;
wire [11:0] rgb_out;
pause #(4,4,4,48) pause
(
	.*,
	.user_button(m_pause),
	.pause_request(hs_pause),
	.options(~status[26:25])
);

wire hblank, vblank;
wire hs, vs;
wire [3:0] r,g,b;

reg ce_pix;
always @(posedge clk_sys) begin
        reg [2:0] div;

        div <= div + 1'd1;
        ce_pix <= !div;
end

wire rotate_ccw = 0;
wire flip = 0;
wire video_rotated;

// The rotation framebuffer shares the DDR port with the RetroAchievements
// mirror (see below), so its DDRAM outputs go through the RA mux.
wire  [7:0] rot_burstcnt, rot_be;
wire [28:0] rot_addr;
wire [63:0] rot_din;
wire        rot_we, rot_rd;

screen_rotate screen_rotate
(
	.*,
	.DDRAM_CLK(),
	.DDRAM_BURSTCNT(rot_burstcnt),
	.DDRAM_ADDR(rot_addr),
	.DDRAM_DIN(rot_din),
	.DDRAM_BE(rot_be),
	.DDRAM_WE(rot_we),
	.DDRAM_RD(rot_rd)
);

wire [3:0] hs_offset = status[31:28];
wire [3:0] vs_offset = status[35:32];
hvsync_gen #(.HS_POS(32), .VS_POS(13)) hvsync_gen
(
	.clk(CLK_VIDEO),
	.ce_pix(ce_pix),
	.hblank(hblank),
	.vblank(vblank),
	.hs_offset(hs_offset),
	.vs_offset(vs_offset),

	.hsync_o(hs),
	.vsync_o(vs)
);

arcade_video #(270,12) arcade_video
(
        .*,

        .clk_video(clk_sys),

        .RGB_in(rgb_out),
        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(hs),
        .VSync(vs),

        .fx(status[5:3])
);


wire [7:0] audio;
assign AUDIO_L = {audio, audio};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

wire reset;
assign reset = RESET | status[0] | ioctl_download | buttons[1];
wire rom_download = ioctl_download && !ioctl_index;

wire clk_6M;

// RetroAchievements tap (see RETROACHIEVEMENTS below)
wire        ra_cpu_we, ra_snd_we;
wire [15:0] ra_cpu_addr;
wire [10:0] ra_snd_addr;
wire  [7:0] ra_cpu_do, ra_snd_do;

bombjack_top bombjack_top
(
	.reset(reset),

	.clk_48M(clk_sys),
	.clk_6M(clk_6M),

	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr & rom_download),

	.p1_start(m_start1),
	.p1_coin(m_coin),
	.p1_jump(m_fire),
	.p1_down(m_down),
	.p1_up(m_up),
	.p1_left(m_left),
	.p1_right(m_right),

	.p2_start(m_start2),
	.p2_coin(m_coin),
	.p2_jump(m_fire_2),
	.p2_down(m_down_2),
	.p2_up(m_up_2),
	.p2_left(m_left_2),
	.p2_right(m_right_2),

	.SW_DEMOSOUNDS(~status[7]),
	.SW_CABINET(~status[12]),
	.SW_LIVES(status[9:8]),
	.SW_ENEMIES(status[14:13]),
	.SW_BIRDSPEED(status[19:18]),
	.SW_BONUS(status[17:15]),

	.VGA_R(r),
	.VGA_G(g),
	.VGA_B(b),
//	.VGA_HS(hs),
//	.VGA_VS(vs),
	.O_VBLANK(vblank),
	.O_HBLANK(hblank),

	.audio(audio),

	.pause(pause_cpu),

	.hs_address(hs_address),
	.hs_data_out(hs_data_out),
	.hs_data_in(hs_data_in),
	.hs_write(hs_write),
	.flip_screen(status[23]),

	.ra_we(ra_cpu_we),
	.ra_addr(ra_cpu_addr),
	.ra_do(ra_cpu_do),
	.ra_snd_we(ra_snd_we),
	.ra_snd_addr(ra_snd_addr),
	.ra_snd_do(ra_snd_do)
);

// HISCORE SYSTEM
// --------------

wire [15:0] hs_address;
wire [7:0] hs_data_in;
wire [7:0] hs_data_out;
wire hs_write;
wire hs_pause;
wire hs_configured;

hiscore #(
	.HS_ADDRESSWIDTH(16),
	.CFG_ADDRESSWIDTH(4),
	.CFG_LENGTHWIDTH(2)
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.autosave(status[27]),
	.ram_address(hs_address),
	.data_from_ram(hs_data_out),
	.data_to_ram(hs_data_in),
	.data_from_hps(ioctl_dout),
	.data_to_hps(ioctl_din),
	.ram_write(hs_write),
	.ram_intent_read(),
	.ram_intent_write(),
	.pause_cpu(hs_pause),
	.configured(hs_configured)
);

///////////////////   RETROACHIEVEMENTS   //////////////////
//
// RAM mirror for the RetroAchievements fork of Main_MiSTer (bombjack_ra_mirror.v,
// from jotego's jtframe via the RA jtcores fork). RA arcade sets are written
// against FinalBurn Neo, whose Bomb Jack driver (d_bombjack.cpp) exposes the
// MemIndex concatenation as "All Ram":
//     0x0000 DrvZ80RAM0 0x1000  main Z80 8000-8FFF
//     0x1000 DrvZ80RAM1 0x0400  sound Z80 4000-43FF
//     0x1400 DrvVidRAM  0x0400  main Z80 9000-93FF
//     0x1800 DrvColRAM  0x0400  main Z80 9400-97FF
//     0x1C00 DrvPalRAM  0x0100  main Z80 9C00-9CFF
//     0x1D00 DrvSprRAM  0x0100  main Z80 9800-98FF
// The Z80s are 8-bit: shadow byte k is RA address k; the ARM region table is
// the identity {0, 0x1E00, 0}.
//
// The CPUs run on clk_12M, a ripple clock divided from clk_sys, and the
// hiscore port writes on clk_sys in pulses too short for clk_12M. So the tap
// works on clk_sys: a CPU write cycle (MREQ+WR held for ~18 clk_sys clocks) is
// only taken once two consecutive samples agree on strobe, address and data,
// and the older sample is written, so a sample caught while the bus changes
// is never used. The hiscore writes are taken directly.
//
// The only other DDR client is the screen rotation framebuffer, which runs on
// CLK_VIDEO (= clk_sys), ignores DDRAM_BUSY and writes one pixel per CE_PIXEL
// while VGA_DE is high. The mirror only starts a copy once VGA_DE has been low
// for 4096 clocks (85 us, longer than any HBlank): the copy (1k qwords, ~25 us)
// then runs in VBlank and the framebuffer never loses a write. Held off during
// ROM download.

function automatic [16:0] ra_map_main(input [15:0] a);  // {valid, offset}
	casez (a)
		16'b1000_????_????_????: ra_map_main = { 1'b1, 4'h0, a[11:0] };          // 8000-8FFF
		16'b1001_00??_????_????: ra_map_main = { 1'b1, 6'b000101, a[9:0] };      // 9000 -> 0x1400
		16'b1001_01??_????_????: ra_map_main = { 1'b1, 6'b000110, a[9:0] };      // 9400 -> 0x1800
		16'b1001_1000_????_????: ra_map_main = { 1'b1, 8'h1D, a[7:0] };          // 9800 -> 0x1D00
		16'b1001_1100_????_????: ra_map_main = { 1'b1, 8'h1C, a[7:0] };          // 9C00 -> 0x1C00
		default:                 ra_map_main = 17'd0;
	endcase
endfunction

reg        rm_we1, rm_we2, rs_we1, rs_we2;
reg [15:0] rm_a1, rm_a2;
reg [10:0] rs_a1, rs_a2;
reg  [7:0] rm_d1, rm_d2, rs_d1, rs_d2;
always @(posedge clk_sys) begin
	{ rm_we1, rm_a1, rm_d1 } <= { ra_cpu_we, ra_cpu_addr, ra_cpu_do };
	{ rm_we2, rm_a2, rm_d2 } <= { rm_we1, rm_a1, rm_d1 };
	{ rs_we1, rs_a1, rs_d1 } <= { ra_snd_we, ra_snd_addr, ra_snd_do };
	{ rs_we2, rs_a2, rs_d2 } <= { rs_we1, rs_a1, rs_d1 };
end

wire [16:0] rm_map = ra_map_main(rm_a2);
wire [16:0] hs_map = ra_map_main(hs_address);
wire        rm_ok  = rm_we1 & rm_we2 & rm_a1 == rm_a2 & rm_d1 == rm_d2 & rm_map[16];
wire        rs_ok  = rs_we1 & rs_we2 & rs_a1 == rs_a2 & rs_d1 == rs_d2 & rs_a2[10] == 1'b0;

wire [14:0] ra_wr_word;
wire [15:0] ra_wr_din;
wire  [1:0] ra_wr_be;

bombjack_ra_tap_merge #(.N(3)) ra_tap
(
	.clk(clk_sys),
	.we({ rs_ok, rm_ok, hs_write & hs_map[16] }),
	.off({ 16'h1000 + { 6'd0, rs_a2[9:0] }, rm_map[15:0], hs_map[15:0] }),
	.din({ rs_d2, rm_d2, hs_data_in }),
	.ra_wr_word(ra_wr_word),
	.ra_wr_din(ra_wr_din),
	.ra_wr_be(ra_wr_be)
);

reg [1:0] ra_vbl_s;
always @(posedge clk_sys) ra_vbl_s <= { ra_vbl_s[0], vblank };

reg [11:0] ra_de_idle;
always @(posedge clk_sys) begin
	if (VGA_DE) ra_de_idle <= 0;
	else if (~&ra_de_idle) ra_de_idle <= ra_de_idle + 1'd1;
end

wire  [7:0] ra_burstcnt, ra_be;
wire [28:0] ra_addr;
wire [63:0] ra_din;
wire        ra_we, ra_active;

bombjack_ra_mirror #(.AW(13)) ra_mirror
(
	.rst(reset),
	.clk(clk_sys),
	.lvbl(~ra_vbl_s[1]),
	.hold(ioctl_download),
	.start_ok(&ra_de_idle),
	.wr_clk(clk_sys),
	.wr_word(ra_wr_word),
	.wr_din(ra_wr_din),
	.wr_be(ra_wr_be),
	.active(ra_active),
	.ddr_busy(DDRAM_BUSY),
	.ddr_burstcnt(ra_burstcnt),
	.ddr_addr(ra_addr),
	.ddr_we(ra_we),
	.ddr_be(ra_be),
	.ddr_din(ra_din)
);

assign DDRAM_CLK      = clk_sys;
assign DDRAM_BURSTCNT = ra_active ? ra_burstcnt : rot_burstcnt;
assign DDRAM_ADDR     = ra_active ? ra_addr     : rot_addr;
assign DDRAM_DIN      = ra_active ? ra_din      : rot_din;
assign DDRAM_BE       = ra_active ? ra_be       : rot_be;
assign DDRAM_WE       = ra_active ? ra_we       : rot_we;
assign DDRAM_RD       = ra_active ? 1'b0        : rot_rd;

endmodule
