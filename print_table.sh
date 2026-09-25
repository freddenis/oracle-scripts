print_table() {
    local -n _arr=$1        # reference to array of rows
    # RAW MODE: Simple comma-separated output ---
    if [[ "${L_RAW}" == "True" ]]; then
        for row in "${_arr[@]}"; do
            echo "$row"
        done
        return 0
    fi
    # Normal (non RAW mode)
    if [[ -n $2 ]]; then
        local -n _align=$2
    else
        local -a _align=()   # just an empty array
    fi

    local sep="|"
    local l_commalist=${3:-${L_COMMALIST}}          # comma-separated column indices, 0 = nothing
    local l_commalimit=${4:-${L_COMMALIMIT}}        # limit for comma list

    # Prepare list of columns for comma-separated lists
    l_commalist=$(echo "${l_commalist}" | tr ',' '\n' | sort -u | grep -v "^$" | paste -sd,)
    local -a l_collist=()
    if [[ "$l_commalist" != "0" && -n "$l_commalist" ]]; then
        IFS=',' read -r -a l_collist <<< "$l_commalist"
    fi

    # Determine max number of columns
    local max_cols=0
    for row in "${_arr[@]}"; do
        IFS=',' read -r -a cols <<< "$row"
        (( ${#cols[@]} > max_cols )) && max_cols=${#cols[@]}
    done

    # Compute max width for each column
    local -a col_widths=()
    for ((c=0; c<max_cols; c++)); do
        local maxlen=0
        for row in "${_arr[@]}"; do
            IFS=',' read -r -a cols <<< "$row"
            [[ -n "${cols[c]}" ]] || cols[c]=""
            (( ${#cols[c]} > maxlen )) && maxlen=${#cols[c]}
        done
        col_widths[c]=$((maxlen + 2))
    done

    # Alignment functions
    center_text() { local text="$1"; local width=$2; local len=${#text}; local spaces=$((width-len)); printf "%*s%s%*s" $((spaces/2)) "" "$text" $((spaces-(spaces/2))) ""; }
    right_text()  { local text="$1 "; local width=$2; printf "%*s" "$width" "$text"; }
    left_text()   { local text="$1"; local width=$2; ((width--)); printf " %-*s" "$width" "$text"; }

    print_line() {
        local total=0
        for w in "${col_widths[@]}"; do ((total+=w+1)); done
        printf '%*s\n' "$total" '' | tr ' ' '-'
    }

    # Save header row for column names
    IFS=',' read -r -a header_row <<< "${_arr[0]}"

    # Print table and build comma lists on the fly
    local row_index=0
    printf "\n"
    declare -A col_lists=()
    for row in "${_arr[@]}"; do
        IFS=',' read -r -a cols <<< "$row"

        # Build comma lists if requested (skip header)
        if ((row_index > 0)); then
            for col_index in "${l_collist[@]}"; do
                ((row_index > l_commalimit)) && continue
                [[ -n "${cols[col_index-1]}" ]] || continue
                if [[ -n "${col_lists[$col_index]}" ]]; then
                    col_lists[$col_index]+=",${cols[col_index-1]}"  # no spaces
                else
                    col_lists[$col_index]="${cols[col_index-1]}"
                fi
            done
        fi

        # Print the row
        printf "$sep"
        for ((c=0; c<max_cols; c++)); do
            local col_align
            if ((row_index == 0)); then
                col_align="c"
            else
                col_align="${_align[c]:-c}"
            fi
            case "$col_align" in
                l) left_text "${cols[c]}" "${col_widths[c]}" ;;
                r) right_text "${cols[c]}" "${col_widths[c]}" ;;
                *) center_text "${cols[c]}" "${col_widths[c]}" ;;
            esac
            printf "$sep"
        done
        echo
        if ((row_index == 0)); then print_line; fi
        ((row_index++))
    done
    print_line

    # Show total number of rows
    if [[ "${L_SHOW_TOTAL}" == "True" ]]; then
        printf "Number of rows: %d"  "$(( --row_index))"
    fi

    # Print comma-separated lists after table
    if [[ "${#l_collist[@]}" -gt 0 ]]; then
        echo
        for col_index in "${l_collist[@]}"; do
            local col_name="${header_row[$((col_index-1))]}"
            echo "$col_name values (up to $l_commalimit): ${col_lists[$col_index]:-}"
        done
    fi
    printf "\n"
}
