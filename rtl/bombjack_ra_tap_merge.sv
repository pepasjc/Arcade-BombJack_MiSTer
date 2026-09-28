//============================================================================
//  RetroAchievements RAM tap merger
//
//  Merges N byte-write sources (each already mapped to its FinalBurn Neo
//  "All Ram" offset) into the single write port of the RA mirror. Every
//  source has a one-deep latch, so strobes that collide in the same clock are
//  written on the following clocks (lowest index first). A source must not
//  strobe again sooner than N clocks after its previous strobe, or the older
//  write is replaced by the newer one; a strobe held for several clocks just
//  keeps re-arming its latch with the current address and data.
//
//  Written for the RetroAchievements ports of the MiSTer arcade cores, after
//  the tap of the Pac-Man port (pacman_ra_tap.sv).
//
//  SPDX-License-Identifier: GPL-3.0-or-later
//============================================================================

module bombjack_ra_tap_merge #(parameter N = 2)
(
    input               clk,
    input      [N-1:0]  we,          // source strobes
    input  [N*16-1:0]   off,         // source i: off[i*16 +: 16], byte offset
    input  [N*8-1:0]    din,         // source i: din[i*8 +: 8]

    // RA mirror write port
    output reg   [14:0] ra_wr_word,
    output reg   [15:0] ra_wr_din,
    output reg    [1:0] ra_wr_be
);

reg  [N-1:0]  pend = 0;
reg  [15:0]   p_off [0:N-1];
reg  [7:0]    p_din [0:N-1];

// lowest pending source
reg [N-1:0] grant;
always_comb begin
    grant = 0;
    for (int i = N-1; i >= 0; i--) if (pend[i]) begin grant = 0; grant[i] = 1'b1; end
end

always_ff @(posedge clk) begin
    ra_wr_be <= 2'b00;
    for (int i = 0; i < N; i++) begin
        if (grant[i]) begin
            ra_wr_word <= p_off[i][15:1];
            ra_wr_din  <= { 2{p_din[i]} };
            ra_wr_be   <= p_off[i][0] ? 2'b10 : 2'b01;
            pend[i]    <= 0;
        end
        if (we[i]) begin
            pend[i]  <= 1;
            p_off[i] <= off[i*16 +: 16];
            p_din[i] <= din[i*8 +: 8];
        end
    end
end

endmodule
