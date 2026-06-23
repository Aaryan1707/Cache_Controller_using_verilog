// Code your design here
module cache_controller (
    input        clk,
    input        rst,
    input        cpu_req,
    input  [7:0] cpu_addr,
    output reg [7:0] cpu_data,
    output reg   hit,
    output reg   miss,
    output reg   ready
);

// Address breakdown: [7:2] = tag (6 bits), [1:0] = index (2 bits)
parameter CACHE_LINES = 4;

reg [7:0] cache_data [0:CACHE_LINES-1];
reg [5:0] tag_array  [0:CACHE_LINES-1];
reg       valid_array[0:CACHE_LINES-1];

// Fake DRAM: address -> data (data = address + 0xAA for easy checking)
reg [7:0] memory [0:255];

// FSM states
parameter IDLE      = 2'd0;
parameter COMPARE   = 2'd1;
parameter ALLOCATE  = 2'd2;

reg [1:0] state;

wire [5:0] tag   = cpu_addr[7:2];
wire [1:0] index = cpu_addr[1:0];

integer i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        hit   <= 0;
        miss  <= 0;
        ready <= 0;
        cpu_data <= 0;
        for (i = 0; i < CACHE_LINES; i = i + 1) begin
            valid_array[i] <= 0;
            tag_array[i]   <= 0;
            cache_data[i]  <= 0;
        end
        // Init fake memory
        for (i = 0; i < 256; i = i + 1)
            memory[i] <= i + 8'hAA;
    end else begin
        case (state)

            IDLE: begin
                hit   <= 0;
                miss  <= 0;
                ready <= 0;
                if (cpu_req)
                    state <= COMPARE;
            end

            COMPARE: begin
                if (valid_array[index] && (tag_array[index] == tag)) begin
                    // HIT
                    hit      <= 1;
                    miss     <= 0;
                    cpu_data <= cache_data[index];
                    ready    <= 1;
                    state    <= IDLE;
                end else begin
                    // MISS
                    hit   <= 0;
                    miss  <= 1;
                    ready <= 0;
                    state <= ALLOCATE;
                end
            end

            ALLOCATE: begin
                // Fetch from memory, fill cache
                cache_data[index]  <= memory[cpu_addr];
                tag_array[index]   <= tag;
                valid_array[index] <= 1;
                cpu_data           <= memory[cpu_addr];
                miss               <= 0;
                ready              <= 1;
                state              <= IDLE;
            end

        endcase
    end
end

endmodule
