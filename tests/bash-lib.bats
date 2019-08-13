#!/usr/bin/env bats
source bash-lib.sh

@test "announce" {
    result=$(announce "Hello World!")
    # echo "$result"
    expected=$(printf "\r\033[32m[INFO]\033[0;39m Hello World!\033[0;39m\n")
    [ "$result" == "$expected" ]
}
