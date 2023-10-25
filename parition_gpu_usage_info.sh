#!/bin/bash
# Description: Straightforward script to check the usage of the selected partitions

# Configure the name, path, threshold and warning message for each partition
# I am lazy to read from a config file (maybe later)
names=("root" "evo1" "evo2" "data")
paths=("/" "/mnt/evo1" "/mnt/evo2" "/media/data")
thres=(95 90 90 97)
purps=("OS" "All purpose" "All Purpose" "Data (prefered)")
warns=(
    "\e[31mWarning\e[0m: The root partition is almost \e[31mFull\e[0m.\nPlease \e[31mMove\e[0m your data to other partitions.\nTraining models in the root partition is \e[31mNOT\e[0m recommended."
    ""
    ""
    ""
)

ext_usage() {
    local usg=$(df -h $1 | tail -1 | awk '{print $5}' | sed 's/%//')
    echo $usg
}

# Generate line with specific len
generate_line() {
    local len=$1
    local symbol=$2
    local line=""

    local sy="$symbol"

    for ((i=0; i<$len; i++)); do
        line+=$sy
    done
    echo -e $line
}

# Simple function to generate a progress bar
generate_progress_bar() {
    local symbol_fill=$1
    local symbol_empty=$2
    local length=$3
    local symbol_fill_color=$4
    local symbol_empty_color=$5
    local bracket_color=$6
    local progress=$7

    local progress_bar=""

    local fil_sy="\e["$symbol_fill_color"m"$symbol_fill"\e[0m"
    local emp_sy="\e["$symbol_empty_color"m"$symbol_empty"\e[0m"

    # Calculate the length of the progress in progress baar
    local progress_length=$(($progress*$length/100))
    
    progress_bar+="\e["$bracket_color"m[\e[0m"
    local i=0
    for ((i=0; i<=$length; i++)); do
        if [ $i -le $progress_length ]; then
            progress_bar+=$fil_sy
        else
            progress_bar+=$emp_sy
        fi
    done
    progress_bar+="\e["$bracket_color"m]\e[0m"

    echo -e $progress_bar
}

# Get the length of partitions
par_len=${#names[@]}

# table format
tab_format="%-5s %-28s %-11s %-15s\n"

# Line
line=$(printf "$tab_format" $(generate_line 5 "-") $(generate_line 28 "-") $(generate_line 11 "-") $(generate_line 15 "-"))

echo "$line"
echo "Partition Usages:"

# Print the header
printf "$tab_format" "Name" "Usage" "Mount" "Purpose"

# Iterate over all other partition
for ((i=0; i<$par_len; i++)); do
    USAGE=$(ext_usage ${paths[$i]})
    if [ $USAGE -gt ${thres[$i]} ]; then
        bar=$(generate_progress_bar "■" "-" 25 31 32 31 $USAGE)
        printf "$tab_format" "${names[$i]}:" "$bar" "${paths[$i]}" "${purps[$i]}"
    else
        bar=$(generate_progress_bar "■" "-" 25 32 0 0 $USAGE)
        printf "$tab_format" "${names[$i]}:" "$bar" "${paths[$i]}" "${purps[$i]}"
    fi
done
echo "$line"

for ((i=0; i<$par_len; i++)); do
    USAGE=$(ext_usage ${paths[$i]})
    if [ $USAGE -gt ${thres[$i]} ]; then
        echo -e "${warns[$i]}"
        echo "$line"
    fi
done

# Add this gpu usage so that everyone can see it at login
# table format
tab_format="%-3s %-28s %-27s\n"

echo "GPU Usages:"

# Print the header
printf "$tab_format" "GPU" "Usage" "Memory"


# Initialize an empty array
gpu_memory_total=()
gpu_memory_used=()
gpu_utilization=()

while IFS= read -r line; do
    gpu_memory_total+=("$line")
done < <(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)

while IFS= read -r line; do
    gpu_memory_used+=("$line")
done < <(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)

while IFS= read -r line; do
    gpu_utilization+=("$line")
done < <(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)

echo $gpu_utilization

# Iterate over all gpu
for ((i=0; i<${#gpu_memory_total[@]}; i++)); do
    # Calculate the usage
    USAGE=$((${gpu_memory_used[$i]}*100/${gpu_memory_total[$i]}))
    if [ $USAGE -gt 80 ]; then
        bar=$(generate_progress_bar "■" "-" 25 31 32 31 $USAGE)
    else
        bar=$(generate_progress_bar "■" "-" 25 32 0 0 $USAGE)
    fi
    if [ ${gpu_utilization[$i]} -gt 80 ]; then
        bar2=$(generate_progress_bar "■" "-" 25 31 32 31 ${gpu_utilization[$i]})
    else
        bar2=$(generate_progress_bar "■" "-" 25 32 0 0 ${gpu_utilization[$i]})
    fi
    printf "$tab_format" "$i:" "$bar2" "$bar"
done

line=$(printf "$tab_format" $(generate_line 3 "-") $(generate_line 28 "-") $(generate_line 28 "-"))

echo "$line"