#!/usr/bin/env bash

# File: https://github.com/HerodotusDev/integrity-calldata-generator/blob/main/cli/verify.sh

if [ $# -ne 5 ]; then
    echo "Usage: $0 <job_id> <layout> <hasher> <stone_version> <memory_verification>"
    exit 1
fi

string_to_hex() {
    input_string="$1"
    hex_string="0x"
    for ((i = 0; i < ${#input_string}; i++)); do
        hex_char=$(printf "%x" "'${input_string:$i:1}")
        hex_string+=$hex_char
    done
    echo "$hex_string"
}

job_id=$1
layout=$(string_to_hex $2)
hasher=$(string_to_hex $3)
stone_version=$(string_to_hex $4)
memory_verification=$(string_to_hex $5)

send_transaction() {
    local retries=5
    local delay=5
    local count=0

    while (( count < retries )); do
        echo "Attempt $((count + 1)) of $retries..."

        sncast \
            --wait \
            invoke \
            --fee-token strk \
            --contract-address "$(<target/calldata/contract_address)" \
            --function "$1" \
            --calldata "$3 $(<$2)"

        local status=$?

        if [[ $status -eq 0 ]]; then
            echo "Transaction successful on attempt $((count + 1))"
            return 0
        else
            echo "Transaction failed with status $status. Retrying in ${delay}s..."
            sleep "$delay"
            count=$((count + 1))
        fi
    done

    echo "Transaction failed after $retries attempts."
    return 1
}

echo ""
echo "Sending verify_proof_initial..."
send_transaction "verify_proof_initial" "target/calldata/initial" "$job_id $layout $hasher $stone_version $memory_verification"

i=1
while true; do
    filename="target/calldata/step${i}"

    if [[ -e "$filename" ]]; then
        echo ""
        echo "Sending verify_proof_step (${i})"
        send_transaction "verify_proof_step" "$filename" "$job_id"
    else
        break
    fi

    ((i++))
done

echo ""
echo "Sending verify_proof_final_and_register_fact"
send_transaction "verify_proof_final_and_register_fact" "target/calldata/final" "$job_id"