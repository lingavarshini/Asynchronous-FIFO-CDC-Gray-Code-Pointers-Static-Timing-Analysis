`timescale 1ns/1ps

module async_fifo_tb;

    reg wr_clk;
    reg rd_clk;
    reg reset;

    reg wr_en;
    reg rd_en;

    reg [7:0] data_in;
    wire [7:0] data_out;

    wire [3:0] wr_ptr;
    wire [3:0] rd_ptr;

    wire [3:0] wr_gray;
    wire [3:0] rd_gray;

    wire [3:0] wr_gray_sync_rd;
    wire [3:0] rd_gray_sync_wr;

    wire empty;
    wire full;


    // ==========================================
    // DUT
    // ==========================================

    async_fifo uut (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .reset(reset),

        .wr_en(wr_en),
        .rd_en(rd_en),

        .data_in(data_in),
        .data_out(data_out),

        .wr_ptr(wr_ptr),
        .rd_ptr(rd_ptr),

        .wr_gray(wr_gray),
        .rd_gray(rd_gray),

        .wr_gray_sync_rd(wr_gray_sync_rd),
        .rd_gray_sync_wr(rd_gray_sync_wr),

        .empty(empty),
        .full(full)
    );


    // ==========================================
    // WRITE CLOCK
    // ==========================================

    initial begin
        wr_clk = 0;
        forever #5 wr_clk = ~wr_clk;
    end


    // ==========================================
    // READ CLOCK
    // ==========================================

    initial begin
        rd_clk = 0;
        forever #7 rd_clk = ~rd_clk;
    end


    // ==========================================
    // TEST
    // ==========================================

    initial begin

        reset  = 1;
        wr_en  = 0;
        rd_en  = 0;
        data_in = 8'b00000000;

        #20;

        reset = 0;


        // --------------------------------------
        // WRITE DATA 1
        // --------------------------------------

        @(posedge wr_clk);
        data_in = 8'b10101010;
        wr_en = 1;

        @(posedge wr_clk);
        wr_en = 0;


        // --------------------------------------
        // WRITE DATA 2
        // --------------------------------------

        @(posedge wr_clk);
        data_in = 8'b11001100;
        wr_en = 1;

        @(posedge wr_clk);
        wr_en = 0;


        // --------------------------------------
        // WAIT FOR CDC
        // --------------------------------------

        #50;


        // --------------------------------------
        // READ DATA 1
        // --------------------------------------

        @(posedge rd_clk);
        rd_en = 1;

        @(posedge rd_clk);
        rd_en = 0;


        #20;


        // --------------------------------------
        // READ DATA 2
        // --------------------------------------

        @(posedge rd_clk);
        rd_en = 1;

        @(posedge rd_clk);
        rd_en = 0;


        #30;

        $stop;

    end

endmodule
