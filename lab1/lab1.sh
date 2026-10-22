#!/bin/bash
set -e

mkdir -p data/task data/programs
cd data

touch lab.txt
touch task/task.txt
touch programs/hello.c programs/hello.py programs/hello.cpp

printf 'gfygivobnkjnkjb\nhjvugvlbjnl\nvgghvtyftrdsd\n];[lpjiugtys\nsrdxcv jb kj\nknjhvfctds\nlpjiuyt6rrtd]\n' > lab.txt

printf 'задание на лабораторную работу 1\nнаписать bash скрипт, который все заархивирует, залогирует и будет отправлять на почту 3 дня\n' > task/task.txt

cat > programs/hello.c <<'EOF'
#include <stdio.h>
int main() {
    printf("Hello world");
    return 0;
}
EOF

echo 'print("Hello world")' > programs/hello.py

cat > programs/hello.cpp <<'EOF'
#include <iostream>
int main() {
    std::cout << "Hello world";
    return 0;
}
EOF

cd ..

zip -r data.zip data/ >/dev/null

touch archieve.log
FILENAME=$(basename data.zip)
DATE_CREATE=$(stat -c "%y" data.zip)
ATRIBUTS=$(stat -c "%A" data.zip)
echo "$FILENAME : $DATE_CREATE : $ATRIBUTS" > archieve.log

cat > mail.sh <<'EOF'
#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$BASE_DIR/archieve.log"
ARCHIVE="$BASE_DIR/data.zip"
COUNTER="$BASE_DIR/counter.txt"
TO="nevaliashka2007@mail.ru"
SUBJECT="Лабораторная работа: архив $(date '+%Y-%m-%d %H:%M')"

if [ ! -f "$COUNTER" ]; then echo 3 > "$COUNTER"; fi
DAYS_LEFT=$(cat "$COUNTER")

if [ "$DAYS_LEFT" -le 0 ]; then
    echo "Срок отправки истёк, выход."
    exit 0
fi

if command -v mutt >/dev/null 2>&1; then
    echo "Осталось дней: $DAYS_LEFT" | mutt -s "$SUBJECT" -a "$LOG" -a "$ARCHIVE" -- "$TO"
elif command -v mail >/dev/null 2>&1; then
    echo "Осталось дней: $DAYS_LEFT" | mail -s "$SUBJECT" -A "$LOG" -A "$ARCHIVE" "$TO"
else
    echo "Не найден почтовый клиент (mail). Установите mailutils." >&2
    exit 1
fi

DAYS_LEFT=$((DAYS_LEFT - 1))
echo "$DAYS_LEFT" > "$COUNTER"
echo "$(date '+%Y-%m-%d %H:%M:%S') отправлено, осталось дней: $DAYS_LEFT" >> "$BASE_DIR/mail_sent.log"

if [ "$DAYS_LEFT" -eq 0 ]; then
    crontab -l 2>/dev/null | grep -v "$BASE_DIR/mail.sh" | crontab -
fi
EOF

chmod +x mail.sh

echo "3" > counter.txt

CRON_LINE="0 12 * * * $PWD/mail.sh"
(crontab -l 2>/dev/null | grep -v "$PWD/mail.sh"; echo "$CRON_LINE") | crontab -
