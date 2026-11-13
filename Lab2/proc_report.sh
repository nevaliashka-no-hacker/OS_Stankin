#!/bin/bash

set -o pipefail

# значения по умолчанию
count=10
sort_by="cpu"
out_file="proc_report.txt"

# справка
usage() {
    cat <<EOF
Использование: $0 [-n количество] [-s критерий] [-o файл] [-h]

  -n количество   сколько процессов вывести в топ (по умолчанию: 10)
  -s критерий     критерий сортировки: cpu, mem, pid (по умолчанию: cpu)
  -o файл         файл для сохранения отчёта (по умолчанию: proc_report.txt)
  -h              показать эту справку
EOF
}

# разбор аргументов
while getopts ":n:s:o:h" opt; do
    case $opt in
        n) count="$OPTARG" ;;
        s) sort_by="$OPTARG" ;;
        o) out_file="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) echo "Ошибка: опция -$OPTARG требует аргумент"; exit 1 ;;
    esac
done

# проверка
if ! [[ "$count" =~ ^[0-9]+$ ]] || (( count == 0 )); then
    echo "Ошибка: -n должно быть положительным целым числом"
    exit 1
fi

case "$sort_by" in
    cpu|mem|pid) ;;
    *) echo "Ошибка: -s должен быть cpu, mem или pid"
       exit 1 ;;
esac

{
    # Блок 1: общая статистика
    echo "=================================================="
    echo "  ОТЧЁТ О ПРОЦЕССАХ"
    echo "  Хост: $(hostname)   Время: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=================================================="
    echo ""

    total=$(ps -e --no-headers | wc -l)

    running=$(ps -eo stat --no-headers  | awk '$1 ~ /^R/ {n++} END {print n+0}')
    sleeping=$(ps -eo stat --no-headers | awk '$1 ~ /^S/ {n++} END {print n+0}')
    zombies=$(ps -eo stat --no-headers  | awk '$1 ~ /^Z/ {n++} END {print n+0}')

    echo "[ОБЩАЯ СТАТИСТИКА]"
    printf "  Всего процессов : %d\n" "$total"
    printf "  Running (R)     : %d\n" "$running"
    printf "  Sleeping (S)    : %d\n" "$sleeping"
    printf "  Zombie (Z)      : %d\n" "$zombies"
    echo ""

    # Блок 2: топ-N процессов
    case "$sort_by" in
        cpu) sort_opt="-pcpu" ;;
        mem) sort_opt="-pmem" ;;
        pid) sort_opt="pid"  ;;
    esac

    sort_label=$(echo "$sort_by" | tr '[:lower:]' '[:upper:]')
    echo "[ТОП-$count ПО $sort_label]"
    printf "  %-8s %-10s %6s %6s %-6s %s\n" \
           "PID" "USER" "%CPU" "%MEM" "STAT" "COMMAND"

    ps -eo pid,user,pcpu,pmem,stat,comm --sort="$sort_opt" \
        | head -n $((count + 1)) \
        | tail -n +2 \
        | awk '{printf "  %-8s %-10s %6s %6s %-6s %s\n", $1, $2, $3, $4, $5, $6}'
    echo ""

    # Блок 3: зомби-процессы
    echo "[ЗОМБИ-ПРОЦЕССЫ]"
    zombie_list=$(ps -eo pid,ppid,stat,comm --no-headers | awk '$3 ~ /^Z/')
    if [[ -z "$zombie_list" ]]; then
        echo "  Не обнаружено."
    else
        echo "  Обнаружены зомби (PID, PPID, STAT, COMMAND):"
        echo "$zombie_list" | awk '{printf "  PID=%-8s PPID=%-8s STAT=%-4s %s\n", $1, $2, $3, $4}'
        echo "  Примечание: зомби нельзя убить напрямую — нужно завершить"
        echo "  или исправить родительский процесс (PPID)."
    fi
    echo ""

    # Блок 4: процесс с максимальным %MEM 
    echo "[САМЫЙ РЕСУРСОЕМКИЙ ПРОЦЕСС]"
    mem_leader=$(ps -eo pid,user,pmem,comm --sort=-pmem --no-headers | head -n 1)
    if [[ -n "$mem_leader" ]]; then
        # "%%MEM" в printf печатает литеральный "%MEM".
        echo "$mem_leader" | awk '{printf "  PID %s (%s) — %s%% MEM\n", $1, $4, $3}'
    else
        echo "  Не удалось определить."
    fi
    echo ""

    # Блок 5: дерево процессов
    echo "[ДЕРЕВО ПРОЦЕССОВ]"
    if command -v pstree >/dev/null 2>&1; then
        pstree -p | head -n 20 | sed 's/^/  /'
    else
        echo "  ВНИМАНИЕ: утилита pstree не установлена."
        echo "  Установите пакет psmisc (например: sudo apt install psmisc)."
    fi
    echo ""


} 2>&1 | tee "$out_file"
