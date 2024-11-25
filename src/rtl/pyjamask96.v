`define NB_ROUNDS_96    14

`define COL_M0  32'ha3861085
`define COL_M1  32'h63417021
`define COL_M2  32'h692cf280
`define COL_MK  32'hb881b9ca


module pyjamask96(
    input clk,
    input reset_n,
    input load,
    input start,
    input [7:0] byte_in,
    input [7:0] byte_key_in,
    output reg valid,
    output reg [7:0] byte_out 
    );

    // FSM states
    localparam [3:0]  
        IDLE =              4'd0,
        LOAD_STATES =       4'd1,
        PYJAMASK_RND =      4'd2,
        ADD_RND_KEY =       4'd3,
        SUB_BYTES =         4'd4,
        MIX_ROWS =          4'd5,
        FINAL_RND =         4'd6,
        OUT =               4'd7,
        DONE =              4'd8;

    // Store state and keystate
    reg [0:95] state;
    reg [0:127] key_state;

    // State vectors
    reg [2:0] curr_state, next_state;

    // Control signals
    reg load_key_and_state;
    reg load_key;
    reg add_rnd_key;
    reg sub_byte;
    reg mix_row;

    reg [3:0] round_count;
    reg [4:0] byte_count;
    reg [5:0] col_count; 

    // State transition
    always @(posedge clk or posedge reset_n) begin
        if(!reset_n) curr_state <= IDLE;
        else curr_state <= next_state;       
    end

    //==============================================================================
    //=== Control path logic
    //==============================================================================

    always@(*) begin
        case(curr_state)
            IDLE: begin
                if(load) begin
                    load_key_and_state = 1;
                    load_key           = 0;
                    add_rnd_key        = 0;
                    sub_byte           = 0;
                    mix_row            = 0;        
                    next_state         = LOAD_STATES;
                end
                else begin
                    load_key_and_state = 0;
                    load_key           = 0;
                    add_rnd_key        = 0;
                    sub_byte           = 0;
                    mix_row            = 0;                 
                    next_state         = IDLE;
                end
            end

            LOAD_STATES: begin
                if(start) begin
                    load_key_and_state = 0;
                    load_key           = 0;
                    add_rnd_key        = 0;
                    sub_byte           = 0;
                    mix_row            = 0; 
                    next_state         = PYJAMASK_RND;
                end
                else begin
                    load_key_and_state = (byte_count <= 5'hb) ? 1 : 0;
                    load_key           = (byte_count >= 5'hb & byte_count <= 5'hf) ? 1 : 0;
                    add_rnd_key        = 0;
                    sub_byte           = 0;
                    mix_row            = 0;                  
                    next_state         = LOAD_STATES;
                end
            end

            PYJAMASK_RND: begin
                load_key_and_state     = 0;
                load_key               = 0;
                add_rnd_key            = 1;
                sub_byte               = 0;
                mix_row                = 0;                
                next_state             = ADD_RND_KEY;
            end

            ADD_RND_KEY: begin
                load_key_and_state     = 0;
                load_key               = 0;
                add_rnd_key            = 0;
                sub_byte               = 1;
                mix_row                = 0;                 
                next_state             = SUB_BYTES;
            end

            SUB_BYTES: begin
                if(col_count <= 6'h1f) begin 
                    load_key_and_state     = 0;
                    load_key               = 0;
                    add_rnd_key            = 0;
                    sub_byte               = 1;
                    mix_row                = 0; 
                    next_state             = SUB_BYTES;
                end

                else begin
                    load_key_and_state     = 0;
                    load_key               = 0;
                    add_rnd_key            = 0;
                    sub_byte               = 0;
                    mix_row                = 1; 
                    next_state             = MIX_ROWS;      
                end
            end

            MIX_ROWS: begin
                if(round_count == `NB_ROUNDS_96-1) next_state = FINAL_RND;
                else next_state = PYJAMASK_RND;
            end

            FINAL_RND: begin
                next_state             = OUT;
            end


        endcase
    end


    //==============================================================================
    //=== Data path logic
    //==============================================================================
    
    // Load state and key
    always@(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            state <= 96'b0;
            key_state <= 128'b0;
            byte_count <= 5'b0;
        end

        else begin
            if(load_key_and_state) begin
                state <= (state << 8) | byte_in;
                key_state <= (key_state << 8) | byte_key_in;
                byte_count <= byte_count + 1;
            end

            if(load_key) begin
                key_state <= (key_state << 8) | byte_key_in;
                byte_count <= byte_count + 1;
            end
        end
    end

    // Add Round Key
    always@(posedge clk) begin
        if(add_rnd_key) begin
            state <= state ^ key_state[0:95];
        end
    end

    // SubByte
    always@(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            col_count <= 6'b0;
        end

        else if (sub_byte) begin
            case({state[col_count], state[col_count+32], state[col_count+64]})
                3'h0: begin
                    {state[col_count], state[col_count+32], state[col_count+64]} <= 3'h1;
                    col_count <= col_count + 1;
                end

                3'h1: begin
                    {state[col_count], state[col_count+32], state[col_count+64]} <= 3'h3;
                    col_count <= col_count + 1;
                end

                3'h2: begin
                    {state[col_count], state[col_count+32], state[col_count+64]} <= 3'h6;
                    col_count <= col_count + 1;
                end

                3'h3: begin
                    {state[col_count], state[col_count+32], state[col_count+64]} <= 3'h5;
                    col_count <= col_count + 1;
                end

                3'h4: begin
                    {state[col_count], state[col_count+32], state[col_count+64]} <= 3'h2;
                    col_count <= col_count + 1;
                end

                3'h5: begin
                    {state[col_count], state[col_count+32], state[col_count+64]} <= 3'h4;
                    col_count <= col_count + 1;
                end

                3'h6: begin
                    {state[col_count], state[col_count+32], state[col_count+64]} <= 3'h7;
                    col_count <= col_count + 1;
                end

                3'h7: begin
                    {state[col_count], state[col_count+32], state[col_count+64]} <= 3'h0;
                    col_count <= col_count + 1;
                end

                default: begin
                    {state[col_count], state[col_count+32], state[col_count+64]} <= 3'h1;
                    col_count <= col_count + 1;
                end                   

            endcase
        end
    end



endmodule