module async_fifo (
    input  wire       wr_clk,
    input  wire       rd_clk,
    input  wire       reset,

    input  wire       wr_en,
    input  wire       rd_en,

    input  wire [7:0] data_in,
    output reg  [7:0] data_out,

    output reg  [3:0] wr_ptr,
    output reg  [3:0] rd_ptr,

    output wire [3:0] wr_gray,
    output wire [3:0] rd_gray,

    output reg  [3:0] wr_gray_sync_rd,
    output reg  [3:0] rd_gray_sync_wr,

    output wire       empty,
    output wire       full
);

    // ==========================================
    // FIFO MEMORY
    // 8 locations × 8 bits
    // ==========================================

    reg [7:0] memory [0:7];


    // ==========================================
    // INTERNAL SYNCHRONIZER REGISTERS
    // ==========================================

    reg [3:0] wr_gray_sync1;
    reg [3:0] rd_gray_sync1;


    // ==========================================
    // WRITE POINTER
    // ==========================================

    always @(posedge wr_clk or posedge reset) begin

        if (reset)
            wr_ptr <= 4'b0000;

        else if (wr_en && !full)
            wr_ptr <= wr_ptr + 1'b1;

    end


    // ==========================================
    // WRITE DATA INTO MEMORY
    // ==========================================

    always @(posedge wr_clk) begin

        if (wr_en && !full)
            memory[wr_ptr[2:0]] <= data_in;

    end


    // ==========================================
    // READ POINTER
    // ==========================================

    always @(posedge rd_clk or posedge reset) begin

        if (reset)
            rd_ptr <= 4'b0000;

        else if (rd_en && !empty)
            rd_ptr <= rd_ptr + 1'b1;

    end


    // ==========================================
    // READ DATA FROM MEMORY
    // ==========================================

    always @(posedge rd_clk or posedge reset) begin

        if (reset)
            data_out <= 8'b00000000;

        else if (rd_en && !empty)
            data_out <= memory[rd_ptr[2:0]];

    end


    // ==========================================
    // BINARY → GRAY
    // ==========================================

    assign wr_gray = wr_ptr ^ (wr_ptr >> 1);

    assign rd_gray = rd_ptr ^ (rd_ptr >> 1);


    // ==========================================
    // READ GRAY → WRITE CLOCK DOMAIN
    // ==========================================

    always @(posedge wr_clk or posedge reset) begin

        if (reset) begin
            rd_gray_sync1  <= 4'b0000;
            rd_gray_sync_wr <= 4'b0000;
        end

        else begin
            rd_gray_sync1   <= rd_gray;
            rd_gray_sync_wr <= rd_gray_sync1;
        end

    end


    // ==========================================
    // WRITE GRAY → READ CLOCK DOMAIN
    // ==========================================

    always @(posedge rd_clk or posedge reset) begin

        if (reset) begin
            wr_gray_sync1  <= 4'b0000;
            wr_gray_sync_rd <= 4'b0000;
        end

        else begin
            wr_gray_sync1   <= wr_gray;
            wr_gray_sync_rd <= wr_gray_sync1;
        end

    end


    // ==========================================
    // EMPTY
    // ==========================================

    assign empty = (rd_gray == wr_gray_sync_rd);


    // ==========================================
    // FULL
    // ==========================================

    assign full = (wr_gray == {~rd_gray_sync_wr[3:2],
                                rd_gray_sync_wr[1:0]});

endmodule
