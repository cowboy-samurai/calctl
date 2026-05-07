#!/bin/bash
################################################################################
# Caldera REST API Commands for Lab Automation
# 
# This script provides all necessary API commands to manage Caldera operations
# for security training labs and adversary emulation exercises.
#
# Prerequisites:
#   - Caldera server running (default: http://localhost:8888)
#   - API key configured in Caldera config file
#   - Sandcat or other agent deployed and connected to Caldera
#   - 'jq' command-line JSON processor installed
#
# Usage:
#   Source this file to load functions: source caldera_api_lib.sh
#   Or run individual functions as needed
#
# Date: 2026-05-06
# Tested with: Caldera 5.2.0+
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Caldera API endpoint (can be overridden by config or environment variable)
CALDERA_API="${CALDERA_API:-http://localhost:8888/api/rest}"

# Adversary inventory file path
# Check multiple locations (supports dev, user, and system-wide installs)
if [ -z "${ADVERSARY_INVENTORY:-}" ]; then
    if [ -f "$(dirname "${BASH_SOURCE[0]}")/adversaries.json" ]; then
        # Development mode: same directory as library
        ADVERSARY_INVENTORY="$(dirname "${BASH_SOURCE[0]}")/adversaries.json"
    elif [ -f "/usr/local/lib/calctl/adversaries.json" ]; then
        # System-wide install
        ADVERSARY_INVENTORY="/usr/local/lib/calctl/adversaries.json"
    elif [ -f "$HOME/.local/lib/calctl/adversaries.json" ]; then
        # User install
        ADVERSARY_INVENTORY="$HOME/.local/lib/calctl/adversaries.json"
    else
        # Fallback to same directory
        ADVERSARY_INVENTORY="$(dirname "${BASH_SOURCE[0]}")/adversaries.json"
    fi
fi

# Export so it's available to calctl and subprocesses
export ADVERSARY_INVENTORY

# Global variable to hold loaded inventory (simple flags, not associative array)
INVENTORY_LOADED_STATUS=""
INVENTORY_LOADED_FILE=""

################################################################################
# SECTION 1: SETUP AND CONFIGURATION
################################################################################

# Function: Detect Caldera configuration file location
detect_caldera_config() {
    local locations=(
        "${CALDERA_CONFIG_PATH:-}"
        "/opt/caldera/conf/local.yml"
        "/etc/caldera/local.yml"
        "$HOME/.caldera/conf/local.yml"
        "./conf/local.yml"
    )
    
    for loc in "${locations[@]}"; do
        if [ -n "$loc" ] && [ -f "$loc" ]; then
            echo "$loc"
            return 0
        fi
    done
    
    return 1
}

# Function: Set API key from Caldera config
set_api_key() {
    echo -e "${BLUE}[*] Extracting API key from Caldera configuration...${NC}"
    
    local config_file=$(detect_caldera_config)
    
    if [ -z "$config_file" ]; then
        echo -e "${RED}[!] ERROR: Caldera configuration file not found${NC}"
        echo -e "${YELLOW}    Searched locations:${NC}"
        echo -e "${YELLOW}      - /opt/caldera/conf/local.yml${NC}"
        echo -e "${YELLOW}      - /etc/caldera/local.yml${NC}"
        echo -e "${YELLOW}      - ~/.caldera/conf/local.yml${NC}"
        echo -e "${YELLOW}      - ./conf/local.yml${NC}"
        echo -e "${YELLOW}    Set CALDERA_CONFIG_PATH to specify custom location${NC}"
        return 1
    fi
    
    export API_KEY=$(grep "api_key_red:" "$config_file" | awk '{print $2}')
    
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}[!] ERROR: API key not found in $config_file${NC}"
        return 1
    fi
    
    echo -e "${GREEN}[✓] API key set successfully (from $config_file)${NC}"
    return 0
}

# Function: Verify Caldera server is accessible
check_caldera_server() {
    echo -e "${BLUE}[*] Checking Caldera server status...${NC}"
    
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}[!] ERROR: API_KEY not set. Run set_api_key first.${NC}"
        return 1
    fi
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d '{"index":"operations"}')
    
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}[✓] Caldera server is accessible${NC}"
        return 0
    else
        echo -e "${RED}[!] ERROR: Caldera server returned HTTP $response${NC}"
        return 1
    fi
}

# Function: Load adversary inventory from JSON file
load_adversary_inventory() {
    echo -e "${BLUE}[*] Loading adversary inventory from $ADVERSARY_INVENTORY...${NC}"
    
    if [ ! -f "$ADVERSARY_INVENTORY" ]; then
        echo -e "${RED}[!] ERROR: Adversary inventory file not found: $ADVERSARY_INVENTORY${NC}"
        return 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}[!] ERROR: 'jq' command not found${NC}"
        echo -e "${YELLOW}    Install with: dnf install jq${NC}"
        echo -e "${YELLOW}    Or visit: https://jqlang.github.io/jq/${NC}"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq -e '.courses' "$ADVERSARY_INVENTORY" >/dev/null 2>&1; then
        echo -e "${RED}[!] ERROR: Invalid JSON structure in $ADVERSARY_INVENTORY${NC}"
        return 1
    fi
    
    # Mark as loaded
    INVENTORY_LOADED_STATUS="loaded"
    INVENTORY_LOADED_FILE="$ADVERSARY_INVENTORY"
    
    echo -e "${GREEN}[✓] Adversary inventory loaded successfully${NC}"
    
    # Show summary
    local course_count=$(jq '.courses | keys | length' "$ADVERSARY_INVENTORY")
    echo -e "${BLUE}    Courses available: $course_count${NC}"
    
    jq -r '.courses | to_entries[] | "    - " + .key + ": " + .value.name' "$ADVERSARY_INVENTORY"
    
    return 0
}

# Function: Get lab metadata from inventory
get_lab_metadata() {
    local course="$1"
    local lab_id="$2"
    
    if [ -z "$course" ] || [ -z "$lab_id" ]; then
        echo -e "${RED}[!] ERROR: Usage: get_lab_metadata <course> <lab_id>${NC}"
        echo -e "${YELLOW}    Example: get_lab_metadata esend 3.2a${NC}"
        return 1
    fi
    
    # Auto-load inventory if not loaded (redirect output to stderr to keep stdout clean)
    if [ "$INVENTORY_LOADED_STATUS" != "loaded" ]; then
        if ! load_adversary_inventory >&2; then
            return 1
        fi
    fi
    
    # Query lab metadata
    local lab_data=$(jq -e ".courses.\"$course\".labs[] | select(.id == \"$lab_id\")" "$ADVERSARY_INVENTORY" 2>/dev/null)
    
    if [ -z "$lab_data" ]; then
        echo -e "${RED}[!] ERROR: Lab not found: $course/$lab_id${NC}" >&2
        echo -e "${YELLOW}    Run 'list_inventory_labs $course' to see available labs${NC}" >&2
        return 1
    fi
    
    echo "$lab_data"
    return 0
}

# Function: List all courses in inventory
list_inventory_courses() {
    # Auto-load inventory if not loaded
    if [ "$INVENTORY_LOADED_STATUS" != "loaded" ]; then
        if ! load_adversary_inventory; then
            return 1
        fi
    fi
    
    echo -e "${BLUE}[*] Available Courses:${NC}"
    echo ""
    
    jq -r '.courses | to_entries[] | .key + ": " + .value.name + " (" + (.value.labs | length | tostring) + " labs)"' "$ADVERSARY_INVENTORY" | while read -r line; do
        echo -e "  ${BLUE}$line${NC}"
    done
    
    echo ""
}

# Function: List all labs for a course
list_inventory_labs() {
    local course="$1"
    
    if [ -z "$course" ]; then
        echo -e "${RED}[!] ERROR: Usage: list_inventory_labs <course>${NC}"
        echo -e "${YELLOW}    Example: list_inventory_labs esend${NC}"
        return 1
    fi
    
    # Auto-load inventory if not loaded
    if [ "$INVENTORY_LOADED_STATUS" != "loaded" ]; then
        if ! load_adversary_inventory; then
            return 1
        fi
    fi
    
    local course_name=$(jq -r ".courses.\"$course\".name // \"null\"" "$ADVERSARY_INVENTORY")
    
    if [ "$course_name" = "null" ]; then
        echo -e "${RED}[!] ERROR: Course not found: $course${NC}"
        echo -e "${YELLOW}    Run 'list_inventory_courses' to see available courses${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[*] Labs for $course ($course_name):${NC}"
    echo ""
    
    jq -r ".courses.\"$course\".labs[] | \"Lab \" + .id + \": \" + .name + \" (\" + (.abilities | tostring) + \" abilities, ~\" + ((.duration_seconds / 60 | floor) | tostring) + \"min, \" + .success_rate + \" success)\"" "$ADVERSARY_INVENTORY" | while read -r line; do
        echo -e "  ${BLUE}$line${NC}"
    done
    
    echo ""
}

################################################################################
# SECTION 2: AGENT MANAGEMENT
################################################################################

# Function: List all connected agents
list_agents() {
    echo -e "${BLUE}[*] Listing all connected agents...${NC}"
    
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}[!] ERROR: API_KEY not set. Run set_api_key first.${NC}"
        return 1
    fi
    
    curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d '{"index":"agents"}' \
        | jq -r '.[] | "\(.paw) | \(.host) | \(.platform) | \(.privilege) | Last seen: \(.last_seen)"'
}

# Function: Get agent details by PAW
get_agent() {
    local paw="$1"
    
    if [ -z "$paw" ]; then
        echo -e "${RED}[!] ERROR: PAW required. Usage: get_agent <paw>${NC}"
        echo -e "${YELLOW}    Tip: Run 'check_windows_agent' to list available agents and their PAWs${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[*] Getting details for agent $paw...${NC}"
    
    curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"agents\",\"paw\":\"$paw\"}" \
        | jq '.'
}

# Function: Check if agent is alive based on last_seen timestamp
is_agent_alive() {
    local paw="$1"
    local max_age_seconds="${2:-180}"  # Default: 3 minutes (3x the typical sleep_max of 60s)
    
    if [ -z "$paw" ]; then
        echo -e "${RED}[!] ERROR: PAW required. Usage: is_agent_alive <paw> [max_age_seconds]${NC}"
        return 1
    fi
    
    local agent_data=$(curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"agents\",\"paw\":\"$paw\"}")
    
    local last_seen=$(echo "$agent_data" | jq -r '.[0].last_seen // empty')
    local sleep_max=$(echo "$agent_data" | jq -r '.[0].sleep_max // 60')
    
    if [ -z "$last_seen" ]; then
        echo -e "${RED}[✗] Agent not found${NC}"
        return 1
    fi
    
    # Convert last_seen to epoch time
    local last_seen_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$last_seen" "+%s" 2>/dev/null || date -d "$last_seen" "+%s" 2>/dev/null)
    local current_epoch=$(date -u "+%s")
    local age_seconds=$((current_epoch - last_seen_epoch))
    
    # Calculate acceptable threshold (sleep_max * 3 or custom max_age)
    local threshold=$((sleep_max * 3))
    if [ "$max_age_seconds" != "180" ]; then
        threshold=$max_age_seconds
    fi
    
    echo -e "${BLUE}[*] Agent: $paw${NC}"
    echo -e "    Last seen: $last_seen"
    echo -e "    Age: ${age_seconds}s (threshold: ${threshold}s)"
    
    if [ "$age_seconds" -le "$threshold" ]; then
        echo -e "${GREEN}[✓] Agent is ALIVE${NC}"
        return 0
    else
        echo -e "${RED}[✗] Agent is DEAD (last seen ${age_seconds}s ago)${NC}"
        return 1
    fi
}

# Function: Check if Windows agent is connected and alive
check_windows_agent() {
    echo -e "${BLUE}[*] Checking for connected Windows agent...${NC}"
    
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}[!] ERROR: API_KEY not set. Run set_api_key first.${NC}"
        return 1
    fi
    
    local agents_json=$(curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d '{"index":"agents"}')
    
    local agent_count=$(echo "$agents_json" | jq '[.[] | select(.platform == "windows" and .privilege == "Elevated")] | length')
    
    if [ "$agent_count" -gt 0 ]; then
        echo -e "${GREEN}[✓] Found $agent_count elevated Windows agent(s)${NC}"
        echo ""
        
        # Show agent details with alive status
        echo "$agents_json" | jq -r '.[] | select(.platform == "windows" and .privilege == "Elevated") | 
            [.paw, .host, .username, .last_seen, .sleep_max] | @tsv' | while IFS=$'\t' read -r paw host username last_seen sleep_max; do
            
            # Calculate age
            local last_seen_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$last_seen" "+%s" 2>/dev/null || date -d "$last_seen" "+%s" 2>/dev/null)
            local current_epoch=$(date -u "+%s")
            local age_seconds=$((current_epoch - last_seen_epoch))
            local threshold=$((sleep_max * 3))
            
            echo -e "  ${BLUE}PAW:${NC} $paw"
            echo -e "  ${BLUE}Host:${NC} $host"
            echo -e "  ${BLUE}User:${NC} $username"
            echo -e "  ${BLUE}Last Seen:${NC} $last_seen (${age_seconds}s ago)"
            
            if [ "$age_seconds" -le "$threshold" ]; then
                echo -e "  ${GREEN}Status: ALIVE ✓${NC}"
            else
                echo -e "  ${RED}Status: DEAD ✗ (exceeded ${threshold}s threshold)${NC}"
            fi
            echo ""
        done
        
        return 0
    else
        echo -e "${RED}[!] No elevated Windows agents found${NC}"
        return 1
    fi
}

# Function: Wait for agent to connect (with timeout)
wait_for_agent() {
    local timeout="${1:-300}"  # Default 5 minutes
    local interval=10
    local elapsed=0
    
    echo -e "${BLUE}[*] Waiting for Windows agent to connect (timeout: ${timeout}s)...${NC}"
    
    while [ $elapsed -lt $timeout ]; do
        if check_windows_agent >/dev/null 2>&1; then
            echo -e "${GREEN}[✓] Agent connected after ${elapsed}s${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}[⏳] Waiting for agent... (${elapsed}s/${timeout}s)${NC}"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo -e "${RED}[!] Timeout waiting for agent after ${timeout}s${NC}"
    return 1
}

# Function: Check agent health (fail-fast for automation workflows)
check_agent_health() {
    local max_age_seconds="${1:-180}"  # Default: 3 minutes
    
    echo -e "${BLUE}[*] Checking agent health (fail-fast mode)...${NC}"
    
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}[!] ERROR: API_KEY not set. Run set_api_key first.${NC}"
        return 3  # Exit code 3: Agent health check failed
    fi
    
    local agents_json=$(curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d '{"index":"agents"}')
    
    local agent_count=$(echo "$agents_json" | jq '[.[] | select(.platform == "windows" and .privilege == "Elevated")] | length')
    
    if [ "$agent_count" -eq 0 ]; then
        echo -e "${RED}[✗] FAIL: No elevated Windows agents found${NC}"
        return 3  # Exit code 3: No agent
    fi
    
    # Get first elevated Windows agent
    local agent_data=$(echo "$agents_json" | jq '[.[] | select(.platform == "windows" and .privilege == "Elevated")][0]')
    local paw=$(echo "$agent_data" | jq -r '.paw')
    local last_seen=$(echo "$agent_data" | jq -r '.last_seen')
    local sleep_max=$(echo "$agent_data" | jq -r '.sleep_max // 60')
    
    # Calculate age
    local last_seen_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$last_seen" "+%s" 2>/dev/null || date -d "$last_seen" "+%s" 2>/dev/null)
    local current_epoch=$(date -u "+%s")
    local age_seconds=$((current_epoch - last_seen_epoch))
    local threshold=$((sleep_max * 3))
    
    # Use custom threshold if provided
    if [ "$max_age_seconds" != "180" ]; then
        threshold=$max_age_seconds
    fi
    
    echo -e "${BLUE}[*] Agent: $paw${NC}"
    echo -e "    Last seen: $last_seen (${age_seconds}s ago)"
    echo -e "    Threshold: ${threshold}s"
    
    if [ "$age_seconds" -le "$threshold" ]; then
        echo -e "${GREEN}[✓] Agent is ALIVE and ready${NC}"
        export AGENT_PAW="$paw"  # Export for use in operations
        return 0
    else
        echo -e "${RED}[✗] FAIL: Agent is DEAD (last seen ${age_seconds}s ago, threshold ${threshold}s)${NC}"
        return 3  # Exit code 3: Dead agent
    fi
}

################################################################################
# SECTION 3: OPERATION MANAGEMENT - CREATION
################################################################################

# Function: Create operation in paused state (simplified workflow)
create_operation() {
    local name="$1"
    local adversary_id="$2"
    
    if [ -z "$name" ] || [ -z "$adversary_id" ]; then
        echo -e "${RED}[!] ERROR: Usage: create_operation <name> <adversary_id>${NC}"
        echo -e "${YELLOW}    Example: create_operation \"Lab 3.2(A)\" \"31d8a88e-fbce-46a8-89b7-742cf4b6b2db\"${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[*] Creating operation: $name${NC}"
    echo -e "${BLUE}    Adversary ID: $adversary_id${NC}"
    
    local response=$(curl -s -X PUT "$CALDERA_API" \
        -H "Content-Type: application/json" \
        -H "KEY: $API_KEY" \
        -d "{
            \"index\": \"operations\",
            \"name\": \"$name\",
            \"adversary_id\": \"$adversary_id\",
            \"state\": \"paused\"
        }")
    
    local op_id=$(echo "$response" | jq -r '.[0].id')
    local op_state=$(echo "$response" | jq -r '.[0].state')
    
    if [ "$op_id" != "null" ] && [ -n "$op_id" ]; then
        echo -e "${GREEN}[✓] Operation created successfully${NC}"
        echo -e "${BLUE}    Operation ID: $op_id${NC}"
        echo -e "${BLUE}    State: $op_state${NC}"
        
        # Export for use in other functions
        export OPERATION_ID="$op_id"
        
        return 0
    else
        echo -e "${RED}[!] ERROR: Failed to create operation${NC}"
        echo -e "${RED}    Response: $response${NC}"
        return 1
    fi
}

# Function: Create operation in running state (for automation workflows)
create_operation_running() {
    local name="$1"
    local adversary_id="$2"
    
    if [ -z "$name" ] || [ -z "$adversary_id" ]; then
        echo -e "${RED}[!] ERROR: Usage: create_operation_running <name> <adversary_id>${NC}"
        echo -e "${YELLOW}    Example: create_operation_running \"Lab 1\" \"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\"${NC}"
        return 4  # Exit code 4: Operation creation failed
    fi
    
    echo -e "${BLUE}[*] Creating operation in running state: $name${NC}"
    echo -e "${BLUE}    Adversary ID: $adversary_id${NC}"
    
    local response=$(curl -s -X PUT "$CALDERA_API" \
        -H "Content-Type: application/json" \
        -H "KEY: $API_KEY" \
        -d "{
            \"index\": \"operations\",
            \"name\": \"$name\",
            \"adversary_id\": \"$adversary_id\",
            \"state\": \"running\"
        }")
    
    local op_id=$(echo "$response" | jq -r '.[0].id')
    local op_state=$(echo "$response" | jq -r '.[0].state')
    
    if [ "$op_id" != "null" ] && [ -n "$op_id" ]; then
        echo -e "${GREEN}[✓] Operation created and started${NC}"
        echo -e "${BLUE}    Operation ID: $op_id${NC}"
        echo -e "${BLUE}    State: $op_state${NC}"
        
        # Export for use in other functions
        export OPERATION_ID="$op_id"
        
        return 0
    else
        echo -e "${RED}[!] ERROR: Failed to create operation${NC}"
        echo -e "${RED}    Response: $response${NC}"
        return 4  # Exit code 4: Operation creation failed
    fi
}

# Function: Create operation for Lab 3.2(A) - Malware Prevention (Demo)
create_lab_3_2a_operation() {
    create_operation \
        "Lab 3.2(A) - Malware Protection Prevent" \
        "31d8a88e-fbce-46a8-89b7-742cf4b6b2db"
}

# Function: Create operation for Lab 3.2(B) - Malware Prevention (Students)
create_lab_3_2b_operation() {
    create_operation \
        "Lab 3.2(B) - Malware Protection Prevent" \
        "d58254e3-e499-49df-ba77-46f4db2d47c7"
}

# Function: Create operation for Lab 3.2(C) - Malware Detection
create_lab_3_2c_operation() {
    create_operation \
        "Lab 3.2(C) - Malware Protection Detect" \
        "46663589-91be-4a27-a350-edef754b533a"
}

# Function: Create operation for Lab 3.3 - Memory Threat Protection
create_lab_3_3_operation() {
    create_operation \
        "Lab 3.3 - Memory Threat Protection" \
        "5ce5bb27-fdfd-4d09-81a9-e0d777dc0994"
}

# Function: Create operation for Lab 3.4 - Malicious Behavior Protection
create_lab_3_4_operation() {
    create_operation \
        "Lab 3.4 - Malicious Behavior Protection" \
        "b30d159a-5348-4ba3-905a-4001b86175f7"
}

# Function: Create operation for Lab 4.1 - OSQuery
create_lab_4_1_operation() {
    create_operation \
        "Lab 4.1 - OSQuery" \
        "f9e7caa0-d224-4b6d-b5e3-3e57d64d20d5"
}

################################################################################
# SECTION 4: OPERATION MANAGEMENT - STATE CONTROL
################################################################################

# Function: Resume operation (start execution)
resume_operation() {
    local op_id="${1:-$OPERATION_ID}"
    
    if [ -z "$op_id" ]; then
        echo -e "${RED}[!] ERROR: Operation ID required${NC}"
        echo -e "${YELLOW}    Usage: resume_operation <operation_id>${NC}"
        echo -e "${YELLOW}    Or set OPERATION_ID environment variable${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[*] Resuming operation: $op_id${NC}"
    
    curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"operation\",\"op_id\":\"$op_id\",\"state\":\"running\"}" \
        > /dev/null
    
    echo -e "${GREEN}[✓] Operation resumed (state changed to 'running')${NC}"
    return 0
}

# Function: Pause operation (stop execution)
pause_operation() {
    local op_id="${1:-$OPERATION_ID}"
    
    if [ -z "$op_id" ]; then
        echo -e "${RED}[!] ERROR: Operation ID required${NC}"
        echo -e "${YELLOW}    Usage: pause_operation <operation_id>${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[*] Pausing operation: $op_id${NC}"
    
    curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"operation\",\"op_id\":\"$op_id\",\"state\":\"paused\"}" \
        > /dev/null
    
    echo -e "${GREEN}[✓] Operation paused${NC}"
    return 0
}

################################################################################
# SECTION 5: OPERATION MONITORING
################################################################################

# Function: Get operation status (summary view)
get_operation_status() {
    local op_id="${1:-$OPERATION_ID}"
    
    if [ -z "$op_id" ]; then
        echo -e "${RED}[!] ERROR: Operation ID required${NC}"
        return 1
    fi
    
    curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"operations\",\"id\":\"$op_id\"}" \
        | jq '.[0] | {
            id,
            name,
            state,
            chain_length: (.chain | length),
            total_abilities: (.adversary.atomic_ordering | length),
            percentage: .objective.percentage,
            start
        }'
}

# Function: Get operation details (full response)
get_operation() {
    local op_id="${1:-$OPERATION_ID}"
    
    if [ -z "$op_id" ]; then
        echo -e "${RED}[!] ERROR: Operation ID required${NC}"
        return 1
    fi
    
    curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"operations\",\"id\":\"$op_id\"}" \
        | jq '.[0]'
}

# Function: Check if operation is complete
is_operation_complete() {
    local op_id="${1:-$OPERATION_ID}"
    
    if [ -z "$op_id" ]; then
        echo -e "${RED}[!] ERROR: Operation ID required${NC}"
        return 1
    fi
    
    local response=$(curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"operations\",\"id\":\"$op_id\"}")
    
    local chain_length=$(echo "$response" | jq '.[0].chain | length')
    local total_abilities=$(echo "$response" | jq '.[0].adversary.atomic_ordering | length')
    
    if [ "$chain_length" -eq "$total_abilities" ]; then
        echo -e "${GREEN}[✓] Operation complete: $chain_length/$total_abilities abilities executed${NC}"
        return 0
    else
        echo -e "${YELLOW}[⏳] Operation in progress: $chain_length/$total_abilities abilities executed${NC}"
        return 1
    fi
}

# Function: Monitor operation until complete
monitor_operation() {
    local op_id="${1:-$OPERATION_ID}"
    local interval="${2:-15}"  # Default 15 seconds
    local timeout="${3:-600}"  # Default 10 minutes
    
    if [ -z "$op_id" ]; then
        echo -e "${RED}[!] ERROR: Operation ID required${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[*] Monitoring operation: $op_id${NC}"
    echo -e "${BLUE}    Polling interval: ${interval}s${NC}"
    echo -e "${BLUE}    Timeout: ${timeout}s${NC}"
    
    local elapsed=0
    local last_chain_length=0
    
    while [ $elapsed -lt $timeout ]; do
        local response=$(curl -s -X POST "$CALDERA_API" \
            -H "KEY: $API_KEY" \
            -d "{\"index\":\"operations\",\"id\":\"$op_id\"}")
        
        local state=$(echo "$response" | jq -r '.[0].state')
        local chain_length=$(echo "$response" | jq '.[0].chain | length')
        local total_abilities=$(echo "$response" | jq '.[0].adversary.atomic_ordering | length')
        
        # Show progress if chain length changed
        if [ "$chain_length" -ne "$last_chain_length" ]; then
            echo -e "${BLUE}[${elapsed}s] State: $state | Progress: $chain_length/$total_abilities abilities${NC}"
            
            # Show last executed ability (only if final status is available)
            if [ "$chain_length" -gt 0 ]; then
                local last_ability=$(echo "$response" | jq -r '.[0].chain[-1].ability.name')
                local last_status=$(echo "$response" | jq -r '.[0].chain[-1].status')
                
                # Only show status if we have a final result (not pending -3)
                if [ "$last_status" -ge 0 ] 2>/dev/null || [ "$last_status" -eq 124 ] 2>/dev/null; then
                    if [ "$last_status" -eq 0 ]; then
                        echo -e "${GREEN}  ✓ Last ability: $last_ability (status: $last_status)${NC}"
                    elif [ "$last_status" -eq 124 ]; then
                        echo -e "${YELLOW}  ⚠ Last ability: $last_ability (status: $last_status - timeout)${NC}"
                    else
                        echo -e "${RED}  ✗ Last ability: $last_ability (status: $last_status)${NC}"
                    fi
                fi
            fi
            
            last_chain_length=$chain_length
        fi
        
        # Check if complete (all abilities executed AND last ability has final status)
        if [ "$chain_length" -eq "$total_abilities" ]; then
            # Wait for final status (status >= 0 means agent reported back)
            local last_status=$(echo "$response" | jq -r '.[0].chain[-1].status')
            if [ "$last_status" -ge 0 ] 2>/dev/null || [ "$last_status" -eq 124 ] 2>/dev/null; then
                echo -e "${GREEN}[✓] Operation complete after ${elapsed}s${NC}"
                echo -e "${GREEN}    All $total_abilities abilities executed${NC}"
                return 0
            else
                # Chain complete but waiting for agent to report final status
                echo -e "${YELLOW}[${elapsed}s] Waiting for final status (current: $last_status)...${NC}"
            fi
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo -e "${RED}[!] Timeout monitoring operation after ${timeout}s${NC}"
    return 1
}

# Function: Get operation execution summary
get_operation_summary() {
    local op_id="${1:-$OPERATION_ID}"
    
    if [ -z "$op_id" ]; then
        echo -e "${RED}[!] ERROR: Operation ID required${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[*] Operation Execution Summary${NC}"
    echo -e "${BLUE}    Operation ID: $op_id${NC}"
    
    local response=$(curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"operations\",\"id\":\"$op_id\"}")
    
    local name=$(echo "$response" | jq -r '.[0].name')
    local state=$(echo "$response" | jq -r '.[0].state')
    local chain_length=$(echo "$response" | jq '.[0].chain | length')
    local total_abilities=$(echo "$response" | jq '.[0].adversary.atomic_ordering | length')
    local start=$(echo "$response" | jq -r '.[0].start')
    
    echo -e "${BLUE}    Name: $name${NC}"
    echo -e "${BLUE}    State: $state${NC}"
    echo -e "${BLUE}    Progress: $chain_length/$total_abilities abilities${NC}"
    echo -e "${BLUE}    Started: $start${NC}"
    
    # Count success/failures
    local success_count=$(echo "$response" | jq '[.[0].chain[] | select(.status == 0)] | length')
    local timeout_count=$(echo "$response" | jq '[.[0].chain[] | select(.status == 124)] | length')
    local failure_count=$(echo "$response" | jq '[.[0].chain[] | select(.status != 0 and .status != 124)] | length')
    
    echo ""
    echo -e "${GREEN}    Successful: $success_count${NC}"
    if [ "$timeout_count" -gt 0 ]; then
        echo -e "${YELLOW}    Timeouts: $timeout_count${NC}"
    fi
    if [ "$failure_count" -gt 0 ]; then
        echo -e "${RED}    Failed: $failure_count${NC}"
    fi
    
    # Show ability execution details
    if [ "$chain_length" -gt 0 ]; then
        echo ""
        echo -e "${BLUE}[*] Executed Abilities:${NC}"
        echo "$response" | jq -r '.[0].chain[] | "  [\(.status)] \(.ability.name) | Technique: \(.ability.technique_id) | Duration: \(.collect // .finish)"'
    fi
}

# Function: Get detailed failure analysis
get_failure_details() {
    local op_id="${1:-$OPERATION_ID}"
    
    if [ -z "$op_id" ]; then
        echo -e "${RED}[!] ERROR: Operation ID required${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[*] Detailed Failure Analysis${NC}"
    echo -e "${BLUE}    Operation ID: $op_id${NC}"
    echo ""
    
    local response=$(curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"operations\",\"id\":\"$op_id\"}")
    
    local failed_abilities=$(echo "$response" | jq '[.[0].chain[] | select(.status != 0)]')
    local failed_count=$(echo "$failed_abilities" | jq 'length')
    
    if [ "$failed_count" -eq 0 ]; then
        echo -e "${GREEN}[✓] No failures detected - all abilities succeeded${NC}"
        return 0
    fi
    
    echo -e "${RED}[!] Found $failed_count failed ability(ies):${NC}"
    echo ""
    
    echo "$failed_abilities" | jq -r '.[] | 
        "Ability: " + .ability.name + "\n" +
        "  Technique: " + .ability.technique_id + "\n" +
        "  Status Code: " + (.status | tostring) + "\n" +
        "  Command: " + (.ability.executor.command // "N/A") + "\n" +
        "  Output: " + (.output // "(no output)") + "\n" +
        "  Duration: " + (.collect // .finish // "N/A") + "\n"'
}

# Function: Export operation results to JSON file
export_operation_results() {
    local op_id="${1:-$OPERATION_ID}"
    local output_file="$2"
    
    if [ -z "$op_id" ]; then
        echo -e "${RED}[!] ERROR: Operation ID required${NC}"
        return 1
    fi
    
    if [ -z "$output_file" ]; then
        # Auto-generate filename with timestamp
        output_file="operation_${op_id}_$(date +%Y%m%d_%H%M%S).json"
    fi
    
    echo -e "${BLUE}[*] Exporting operation results...${NC}"
    echo -e "${BLUE}    Operation ID: $op_id${NC}"
    echo -e "${BLUE}    Output file: $output_file${NC}"
    
    local response=$(curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"operations\",\"id\":\"$op_id\"}")
    
    # Extract relevant data
    local export_data=$(echo "$response" | jq '.[0] | {
        operation_id: .id,
        name: .name,
        state: .state,
        start_time: .start,
        finish_time: .finish,
        adversary: {
            id: .adversary.adversary_id,
            name: .adversary.name,
            total_abilities: (.adversary.atomic_ordering | length)
        },
        execution: {
            executed_abilities: (.chain | length),
            success_count: ([.chain[] | select(.status == 0)] | length),
            timeout_count: ([.chain[] | select(.status == 124)] | length),
            failure_count: ([.chain[] | select(.status != 0 and .status != 124)] | length)
        },
        abilities: [.chain[] | {
            name: .ability.name,
            technique_id: .ability.technique_id,
            tactic: .ability.tactic,
            status: .status,
            command: (.ability.executor.command // "N/A"),
            output: (.output // ""),
            start: .collect,
            finish: .finish
        }]
    }')
    
    echo "$export_data" > "$output_file"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Results exported successfully${NC}"
        echo -e "${BLUE}    File size: $(du -h $output_file | cut -f1)${NC}"
        return 0
    else
        echo -e "${RED}[!] ERROR: Failed to export results${NC}"
        return 1
    fi
}

# Function: Calculate operation exit code based on success rate
calculate_exit_code() {
    local op_id="${1:-$OPERATION_ID}"
    
    if [ -z "$op_id" ]; then
        return 1
    fi
    
    local response=$(curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"operations\",\"id\":\"$op_id\"}")
    
    local total=$(echo "$response" | jq '.[0].adversary.atomic_ordering | length')
    local success=$(echo "$response" | jq '[.[0].chain[] | select(.status == 0)] | length')
    
    if [ "$total" -eq 0 ]; then
        return 4  # No abilities (operation creation issue)
    fi
    
    # Calculate success rate percentage
    local success_rate=$((success * 100 / total))
    
    # Return exit code based on success rate
    if [ "$success_rate" -ge 75 ]; then
        return 0  # 75-100%: Success
    elif [ "$success_rate" -ge 25 ]; then
        return 1  # 25-74%: Partial success
    else
        return 2  # 0-24%: Low success
    fi
}

################################################################################
# SECTION 6: OPERATION CLEANUP
################################################################################

# Function: Delete operation
delete_operation() {
    local op_id="${1:-$OPERATION_ID}"
    
    if [ -z "$op_id" ]; then
        echo -e "${RED}[!] ERROR: Operation ID required${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[*] Deleting operation: $op_id${NC}"
    
    local response=$(curl -s -X DELETE "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"operations\",\"id\":\"$op_id\"}")
    
    if echo "$response" | grep -q "Delete action completed"; then
        echo -e "${GREEN}[✓] Operation deleted successfully${NC}"
        unset OPERATION_ID
        return 0
    else
        echo -e "${RED}[!] ERROR: Failed to delete operation${NC}"
        echo -e "${RED}    Response: $response${NC}"
        return 1
    fi
}

# Function: List all operations
list_operations() {
    echo -e "${BLUE}[*] Listing all operations...${NC}"
    
    curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d '{"index":"operations"}' \
        | jq -r '.[] | "\(.id) | \(.name) | State: \(.state) | Progress: \(.chain | length)/\(.adversary.atomic_ordering | length)"'
}

# Function: Delete all operations
delete_all_operations() {
    echo -e "${YELLOW}[!] WARNING: This will delete ALL operations${NC}"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${BLUE}[*] Aborted${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[*] Deleting all operations...${NC}"
    
    local op_ids=$(curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d '{"index":"operations"}' \
        | jq -r '.[].id')
    
    local count=0
    for op_id in $op_ids; do
        delete_operation "$op_id" >/dev/null 2>&1
        count=$((count + 1))
    done
    
    echo -e "${GREEN}[✓] Deleted $count operation(s)${NC}"
}

################################################################################
# SECTION 7: AUTOMATION WORKFLOWS (COMBINED OPERATIONS)
################################################################################

# Function: Complete workflow - Create, wait, resume, monitor, cleanup
run_lab_operation() {
    local lab_name="$1"
    local adversary_id="$2"
    local wait_time="${3:-60}"  # Default 60 seconds for environment setup
    
    if [ -z "$lab_name" ] || [ -z "$adversary_id" ]; then
        echo -e "${RED}[!] ERROR: Usage: run_lab_operation <lab_name> <adversary_id> [wait_time]${NC}"
        echo -e "${YELLOW}    Example: run_lab_operation \"Lab 1\" \"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\" 60${NC}"
        return 1
    fi
    
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Running Caldera Lab Operation: $lab_name${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Step 1: Create operation in paused state
    echo -e "${BLUE}[Step 1/5] Creating operation in paused state...${NC}"
    if ! create_operation "$lab_name" "$adversary_id"; then
        echo -e "${RED}[!] Failed to create operation${NC}"
        return 1
    fi
    echo ""
    
    # Step 2: Wait for environment configuration
    echo -e "${BLUE}[Step 2/5] Waiting ${wait_time}s for environment configuration...${NC}"
    echo -e "${YELLOW}    (Use this time to configure security tools, policies, monitoring, etc.)${NC}"
    sleep "$wait_time"
    echo -e "${GREEN}[✓] Environment ready${NC}"
    echo ""
    
    # Step 3: Resume operation
    echo -e "${BLUE}[Step 3/5] Resuming operation...${NC}"
    if ! resume_operation; then
        echo -e "${RED}[!] Failed to resume operation${NC}"
        return 1
    fi
    echo ""
    
    # Step 4: Monitor until complete
    echo -e "${BLUE}[Step 4/5] Monitoring execution...${NC}"
    if ! monitor_operation "$OPERATION_ID" 15 600; then
        echo -e "${RED}[!] Monitoring failed or timed out${NC}"
        return 1
    fi
    echo ""
    
    # Step 5: Show summary
    echo -e "${BLUE}[Step 5/5] Execution summary...${NC}"
    get_operation_summary
    echo ""
    
    # Cleanup prompt
    echo -e "${YELLOW}[?] Delete operation? (yes/no): ${NC}"
    read -p "" cleanup_confirm
    if [ "$cleanup_confirm" = "yes" ]; then
        delete_operation
    else
        echo -e "${BLUE}[*] Operation preserved (ID: $OPERATION_ID)${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Lab Operation Complete!${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
}

# Function: Quick lab runner for Lab 3.2(A)
run_lab_3_2a() {
    run_lab_operation \
        "Lab 3.2(A) - Malware Protection Prevent" \
        "31d8a88e-fbce-46a8-89b7-742cf4b6b2db" \
        "${1:-60}"
}

# Function: Quick lab runner for Lab 3.2(B)
run_lab_3_2b() {
    run_lab_operation \
        "Lab 3.2(B) - Malware Protection Prevent" \
        "d58254e3-e499-49df-ba77-46f4db2d47c7" \
        "${1:-60}"
}

# Function: Quick lab runner for Lab 3.2(C)
run_lab_3_2c() {
    run_lab_operation \
        "Lab 3.2(C) - Malware Protection Detect" \
        "46663589-91be-4a27-a350-edef754b533a" \
        "${1:-60}"
}

# Function: Quick lab runner for Lab 3.3
run_lab_3_3() {
    run_lab_operation \
        "Lab 3.3 - Memory Threat Protection" \
        "5ce5bb27-fdfd-4d09-81a9-e0d777dc0994" \
        "${1:-60}"
}

# Function: Quick lab runner for Lab 3.4
run_lab_3_4() {
    run_lab_operation \
        "Lab 3.4 - Malicious Behavior Protection" \
        "b30d159a-5348-4ba3-905a-4001b86175f7" \
        "${1:-60}"
}

# Function: Quick lab runner for Lab 4.1
run_lab_4_1() {
    run_lab_operation \
        "Lab 4.1 - OSQuery" \
        \"f9e7caa0-d224-4b6d-b5e3-3e57d64d20d5\" \
        \"${1:-60}\"
}

# Function: Automated lab workflow - Run lab operation (agent check, create, monitor, export)
# Use this for CI/CD pipelines, automated testing, or unattended execution
run_lab_automated() {
    local course="$1"
    local lab_id="$2"
    local output_dir="${3:-.}"
    
    if [ -z "$course" ] || [ -z "$lab_id" ]; then
        echo -e "${RED}[!] ERROR: Usage: run_lab_automated <course> <lab_id> [output_dir]${NC}"
        echo -e "${YELLOW}    Example: run_lab_automated mycourse lab-01${NC}"
        echo -e "${YELLOW}    Example: run_lab_automated mycourse lab-02 /tmp/results${NC}"
        return 1
    fi
    
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Automation Mode: $course / Lab $lab_id${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Step 1: Load lab metadata from inventory
    echo -e "${BLUE}[Step 1/5] Loading lab metadata...${NC}"
    local lab_metadata=$(get_lab_metadata "$course" "$lab_id")
    if [ $? -ne 0 ]; then
        echo -e "${RED}[!] Failed to load lab metadata${NC}"
        return 6  # Exit code 6: Invalid inventory
    fi
    
    # Debug: show what we captured
    #echo -e "${YELLOW}[DEBUG] lab_metadata content:${NC}" >&2
    #echo "$lab_metadata" >&2
    #echo -e "${YELLOW}[DEBUG] end of lab_metadata${NC}" >&2
    
    local adversary_id=$(echo "$lab_metadata" | jq -r '.adversary_id')
    local lab_name=$(echo "$lab_metadata" | jq -r '.name')
    local expected_duration=$(echo "$lab_metadata" | jq -r '.duration_seconds')
    
    echo -e "${GREEN}[✓] Lab loaded: $lab_name${NC}"
    echo -e "${BLUE}    Adversary ID: $adversary_id${NC}"
    echo -e "${BLUE}    Expected duration: ~${expected_duration}s${NC}"
    echo ""
    
    # Step 2: Check agent health (fail-fast)
    echo -e "${BLUE}[Step 2/5] Checking agent health...${NC}"
    if ! check_agent_health 180; then
        echo -e "${RED}[!] Agent health check failed - aborting${NC}"
        return 3  # Exit code 3: Agent health failed
    fi
    echo ""
    
    # Step 3: Create operation in running state (no pause, no wait)
    echo -e "${BLUE}[Step 3/5] Creating operation (running state)...${NC}"
    local operation_name="$course-$lab_id: $lab_name"
    if ! create_operation_running "$operation_name" "$adversary_id"; then
        echo -e "${RED}[!] Failed to create operation${NC}"
        return 4  # Exit code 4: Operation creation failed
    fi
    echo ""
    
    # Step 4: Monitor until complete (with extended timeout)
    echo -e "${BLUE}[Step 4/5] Monitoring execution...${NC}"
    local timeout=$((expected_duration + 300))  # Add 5min buffer
    if ! monitor_operation "$OPERATION_ID" 15 "$timeout"; then
        echo -e "${RED}[!] Operation timed out or monitoring failed${NC}"
        
        # Still export results even on timeout
        echo -e "${YELLOW}[*] Exporting partial results...${NC}"
        export_operation_results "$OPERATION_ID" "$output_dir/operation_${course}_${lab_id}_timeout.json"
        
        return 5  # Exit code 5: Operation timeout
    fi
    echo ""
    
    # Step 5: Show summary and export results
    echo -e "${BLUE}[Step 5/5] Generating results...${NC}"
    get_operation_summary
    echo ""
    
    # Export to JSON
    local output_file="$output_dir/operation_${course}_${lab_id}_$(date +%Y%m%d_%H%M%S).json"
    export_operation_results "$OPERATION_ID" "$output_file"
    echo ""
    
    # Show failure details if any
    local response=$(curl -s -X POST "$CALDERA_API" \
        -H "KEY: $API_KEY" \
        -d "{\"index\":\"operations\",\"id\":\"$OPERATION_ID\"}")
    local failure_count=$(echo "$response" | jq '[.[0].chain[] | select(.status != 0 and .status != 124)] | length')
    
    if [ "$failure_count" -gt 0 ]; then
        echo -e "${YELLOW}[*] Detected $failure_count failure(s) - showing details:${NC}"
        echo ""
        get_failure_details
        echo ""
    fi
    
    # Calculate and return exit code based on success rate
    calculate_exit_code "$OPERATION_ID"
    local exit_code=$?
    
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    if [ "$exit_code" -eq 0 ]; then
        echo -e "${GREEN}║  Lab Automation Complete - SUCCESS (Exit Code: $exit_code)${NC}"
    elif [ "$exit_code" -eq 1 ]; then
        echo -e "${YELLOW}║  Lab Automation Complete - PARTIAL SUCCESS (Exit Code: $exit_code)${NC}"
    else
        echo -e "${RED}║  Lab Automation Complete - LOW SUCCESS (Exit Code: $exit_code)${NC}"
    fi
    echo -e "${BLUE}║  Operation preserved for analysis: $OPERATION_ID${NC}"
    echo -e "${BLUE}║  Results exported to: $output_file${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    return $exit_code
}

# Backwards compatibility alias
run_lab_auto() {
    run_lab_automated "$@"
}

# Function: Create adversary template (developer helper)
create_adversary_template() {
    local course="$1"
    
    if [ -z "$course" ]; then
        echo -e "${RED}[!] ERROR: Usage: create_adversary_template <course>${NC}"
        echo -e "${YELLOW}    Example: create_adversary_template esend${NC}"
        echo -e "${YELLOW}    Or run without args to select from available courses${NC}"
        echo ""
        list_inventory_courses
        return 1
    fi
    
    # Auto-load inventory if not loaded
    if [ "$INVENTORY_LOADED_STATUS" != "loaded" ]; then
        if ! load_adversary_inventory; then
            return 1
        fi
    fi
    
    # Verify course exists
    local course_name=$(jq -r ".courses.\"$course\".name // \"null\"" "$ADVERSARY_INVENTORY")
    if [ "$course_name" = "null" ]; then
        echo -e "${RED}[!] ERROR: Course not found: $course${NC}"
        list_inventory_courses
        return 1
    fi
    
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Create New Adversary Template${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Course: $course ($course_name)${NC}"
    echo ""
    
    # Interactive prompts
    read -p "Enter lab ID (e.g., 3.5, 4.2): " lab_id
    read -p "Enter lab name: " lab_name
    read -p "Enter adversary ID (from Caldera Web UI): " adversary_id
    read -p "Enter number of abilities: " abilities
    read -p "Enter estimated duration (seconds): " duration
    read -p "Enter notes (optional): " notes
    
    # Validate inputs
    if [ -z "$lab_id" ] || [ -z "$lab_name" ] || [ -z "$adversary_id" ] || [ -z "$abilities" ] || [ -z "$duration" ]; then
        echo -e "${RED}[!] ERROR: All fields except notes are required${NC}"
        return 1
    fi
    
    # Build JSON entry
    echo ""
    echo -e "${BLUE}[*] Template created! Here's what will be added to adversaries.json:${NC}"
    echo ""
    echo "  {"
    echo "    \"id\": \"$lab_id\","
    echo "    \"adversary_id\": \"$adversary_id\","
    echo "    \"name\": \"$lab_name\","
    echo "    \"abilities\": $abilities,"
    echo "    \"duration_seconds\": $duration,"
    echo "    \"success_rate\": \"TBD\","
    echo "    \"notes\": \"$notes\""
    echo "  }"
    echo ""
    
    echo -e "${BLUE}[*] Copy the above JSON and manually add it to:${NC}"
    echo -e "${YELLOW}    $ADVERSARY_INVENTORY${NC}"
    echo -e "${BLUE}    Under .courses.$course.labs array${NC}"
    echo ""
    echo -e "${BLUE}[*] After adding, test in Caldera Web UI, then run with:${NC}"
    echo -e "${YELLOW}    calctl lab run $course $lab_id${NC}"
    echo ""
    
    return 0
}

################################################################################
# SECTION 8: ADVERSARY PROFILES REFERENCE
################################################################################

# Function: List all available adversary profiles
list_adversaries() {
    echo -e "${BLUE}[*] Available Adversary Profiles (All Tested ✅):${NC}"
    echo ""
    echo -e "${BLUE}Lab 3.2(A) - Malware Protection: Prevent (Demo)${NC}"
    echo "  ID: 31d8a88e-fbce-46a8-89b7-742cf4b6b2db"
    echo "  Abilities: 1 (malware dropper demo)"
    echo "  Duration: ~94 seconds (~1.5 minutes)"
    echo "  Success Rate: 100% (1/1 abilities)"
    echo ""
    echo -e "${BLUE}Lab 3.2(B) - Malware Protection: Prevent (Students)${NC}"
    echo "  ID: d58254e3-e499-49df-ba77-46f4db2d47c7"
    echo "  Abilities: 5 (phishing chain with prevent mode)"
    echo "  Duration: ~165 seconds (~2.75 minutes)"
    echo "  Success Rate: 80% (4/5 abilities)"
    echo ""
    echo -e "${BLUE}Lab 3.2(C) - Malware Protection: Detect (Students)${NC}"
    echo "  ID: 46663589-91be-4a27-a350-edef754b533a"
    echo "  Abilities: 8 (phishing → privilege escalation)"
    echo "  Duration: 405-534 seconds (~7-9 minutes, 24% variance)"
    echo "  Success Rate: 62.5-87.5% (5-7/8 abilities, varies by run)"
    echo ""
    echo -e "${BLUE}Lab 3.3 - Memory Threat Protection${NC}"
    echo "  ID: 5ce5bb27-fdfd-4d09-81a9-e0d777dc0994"
    echo "  Abilities: 3 (process injection emulation)"
    echo "  Duration: ~60 seconds (~1 minute) - Fastest lab"
    echo "  Success Rate: 66.7% (2/3 abilities)"
    echo ""
    echo -e "${BLUE}Lab 3.4 - Malicious Behavior Protection${NC}"
    echo "  ID: b30d159a-5348-4ba3-905a-4001b86175f7"
    echo "  Abilities: 5 (defense evasion and collection)"
    echo "  Duration: ~210 seconds (~3.5 minutes)"
    echo "  Success Rate: 40% (2/5 abilities)"
    echo ""
    echo -e "${BLUE}Lab 4.1 - OSQuery${NC}"
    echo "  ID: f9e7caa0-d224-4b6d-b5e3-3e57d64d20d5"
    echo "  Abilities: 4 (OSQuery detection scenarios)"
    echo "  Duration: ~120 seconds (~2 minutes)"
    echo "  Success Rate: 25% (1/4 abilities) - Lowest success rate"
    echo ""
    echo -e "${YELLOW}Note: All labs tested November 19, 2025${NC}"
    echo -e "${YELLOW}Success rates range 25-100% (partial success is normal)${NC}"
    echo ""
}

################################################################################
# SECTION 9: USAGE EXAMPLES
################################################################################

# Function: Show usage examples
show_examples() {
    cat << 'EXAMPLES'

╔════════════════════════════════════════════════════════════════╗
║  Caldera API Commands - Usage Examples                        ║
╚════════════════════════════════════════════════════════════════╝

SETUP:
------
# 1. Set API key from Caldera config
set_api_key

# 2. Verify Caldera server is accessible
check_caldera_server

# 3. Check for connected Windows agent
check_windows_agent

# 4. Wait for agent to connect (optional)
wait_for_agent 300


MANUAL WORKFLOW:
----------------
# 1. Create operation in paused state
create_operation "Lab 3.2(A)" "31d8a88e-fbce-46a8-89b7-742cf4b6b2db"

# 2. (Configure Elastic environment here)

# 3. Resume operation
resume_operation

# 4. Monitor until complete
monitor_operation

# 5. Get execution summary
get_operation_summary

# 6. Delete operation
delete_operation


AUTOMATED WORKFLOW:
-------------------
# Run complete lab workflow (create, wait, resume, monitor, cleanup)
run_lab_operation "Lab 3.2(A)" "31d8a88e-fbce-46a8-89b7-742cf4b6b2db" 60

# Quick runners for specific labs
run_lab_3_2a      # Lab 3.2(A) - Malware Prevention (Demo)
run_lab_3_2b      # Lab 3.2(B) - Malware Prevention (Students)
run_lab_3_2c      # Lab 3.2(C) - Malware Detection
run_lab_3_3       # Lab 3.3 - Memory Threat Protection
run_lab_3_4       # Lab 3.4 - Malicious Behavior Protection
run_lab_4_1       # Lab 4.1 - OSQuery


MONITORING:
-----------
# Check operation status (summary)
get_operation_status

# Get full operation details
get_operation

# Check if operation is complete
is_operation_complete

# Monitor with custom interval and timeout
monitor_operation "$OPERATION_ID" 20 900  # 20s interval, 15min timeout


CLEANUP:
--------
# Delete specific operation
delete_operation "$OPERATION_ID"

# List all operations
list_operations

# Delete all operations (with confirmation)
delete_all_operations


AGENT MANAGEMENT:
-----------------
# List all agents
list_agents

# Get specific agent details
get_agent "dagkrk"

# Check if agent is alive (based on last_seen timestamp)
is_agent_alive "dagkrk"              # Uses default 3-minute threshold
is_agent_alive "dagkrk" 300          # Custom 5-minute threshold

# Check Windows agent status (shows alive/dead status)
check_windows_agent


ADVERSARY REFERENCE:
--------------------
# List available adversary profiles (legacy)
list_adversaries

# List courses from inventory
list_inventory_courses

# List labs for a specific course
list_inventory_labs red-team-101


AUTOMATION MODE:
--------------------------
# Run lab in automation mode (agent check, create, monitor, export)
run_lab_automated mycourse lab-01
run_lab_automated mycourse lab-02 /tmp/results

# Backwards compatible (deprecated but still works)
run_lab_auto mycourse lab-01

# Exit codes:
# 0 = Success (75-100% success rate)
# 1 = Partial success (25-74% success rate)
# 2 = Low success (0-24% success rate)
# 3 = Agent health check failed
# 4 = Operation creation failed
# 5 = Operation timeout
# 6 = Invalid inventory (lab not found)

# Export operation results to JSON
export_operation_results "$OPERATION_ID" "results.json"

# Get detailed failure analysis
get_failure_details "$OPERATION_ID"

# Check agent health (fail-fast mode)
check_agent_health 180  # 180s threshold


DEVELOPER WORKFLOW:
-------------------
# Load adversary inventory
load_adversary_inventory

# List available courses and labs
list_inventory_courses
list_inventory_labs mycourse

# Create new adversary template (interactive)
create_adversary_template mycourse

# Get lab metadata
get_lab_metadata mycourse lab-01

EXAMPLES
}

################################################################################
# INITIALIZATION
################################################################################

# Auto-run on source (if not disabled)
if [ "${CALDERA_AUTO_INIT:-1}" = "1" ]; then
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Caldera API Commands Loaded                                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Run 'show_examples' to see usage examples${NC}"
    echo ""
    
    # Auto-set API key if config file exists
    if [ -f "/opt/caldera/conf/local.yml" ]; then
        set_api_key
    else
        echo -e "${YELLOW}[!] Caldera config not found at /opt/caldera/conf/local.yml${NC}"
        echo -e "${YELLOW}    Run 'set_api_key' manually after Caldera is configured${NC}"
    fi
    
    # Auto-load adversary inventory if jq is available
    if command -v jq &> /dev/null && [ -f "$ADVERSARY_INVENTORY" ]; then
        load_adversary_inventory
    else
        if ! command -v jq &> /dev/null; then
            echo -e "${YELLOW}[!] 'jq' not installed - inventory features disabled${NC}"
            echo -e "${YELLOW}    Install with: dnf install jq${NC}"
        fi
        if [ ! -f "$ADVERSARY_INVENTORY" ]; then
            echo -e "${YELLOW}[!] Adversary inventory not found: $ADVERSARY_INVENTORY${NC}"
        fi
    fi
fi
