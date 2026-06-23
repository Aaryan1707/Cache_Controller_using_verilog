`timescale 1ns/1ps

module cache_tb;

reg        clk;
reg        rst;
reg        cpu_req;
reg  [7:0] cpu_addr;

wire [7:0] cpu_data;
wire       hit;
wire       miss;
wire       ready;

// Instantiate DUT
cache_controller dut (
    .clk      (clk),
    .rst      (rst),
    .cpu_req  (cpu_req),
    .cpu_addr (cpu_addr),
    .cpu_data (cpu_data),
    .hit      (hit),
    .miss     (miss),
    .ready    (ready)
);

// Clock: 10ns period
always #5 clk = ~clk;

// Task: send one request and wait for ready
task send_request;
    input [7:0] addr;
    input [63:0] label; // unused in display but kept for clarity
    begin
        @(negedge clk);
        cpu_addr <= addr;
        cpu_req  <= 1;
        @(negedge clk);
        cpu_req  <= 0;
        // Wait up to 5 cycles for ready
        repeat (5) begin
            if (!ready) @(negedge clk);
        end
        #1;
        $display("  Addr=0x%02X | hit=%b miss=%b | data=0x%02X | ready=%b",
                  addr, hit, miss, cpu_data, ready);
    end
endtask

initial begin
    $dumpfile("cache_sim.vcd");
    $dumpvars(0, cache_tb);

    clk     = 0;
    rst     = 1;
    cpu_req = 0;
    cpu_addr= 0;

    // Hold reset for 2 cycles
    repeat (2) @(negedge clk);
    rst = 0;
    @(negedge clk);

    $display("==============================================");
    $display("  Direct-Mapped Cache Controller Simulation");
    $display("==============================================");

    // -----------------------------------------------
    // Scenario 1: MISS — first access to address 0x0C
    // -----------------------------------------------
    $display("\n[Scenario 1] First access to 0x0C => expect MISS");
    send_request(8'h0C, 64'd0);

    // -----------------------------------------------
    // Scenario 2: HIT — same address again
    // -----------------------------------------------
    $display("\n[Scenario 2] Same address 0x0C again => expect HIT");
    send_request(8'h0C, 64'd0);

    // -----------------------------------------------
    // Scenario 3: MISS — different address 0x14
    // -----------------------------------------------
    $display("\n[Scenario 3] New address 0x14 => expect MISS");
    send_request(8'h14, 64'd0);

    // -----------------------------------------------
    // Bonus: HIT on 0x14 now
    // -----------------------------------------------
    $display("\n[Bonus]      Same address 0x14 again => expect HIT");
    send_request(8'h14, 64'd0);

    $display("\n==============================================");
    $display("  Simulation complete. Open cache_sim.vcd");
    $display("  in EPWave to view waveforms.");
    $display("==============================================\n");

    #20;
    $finish;
end

endmodule
