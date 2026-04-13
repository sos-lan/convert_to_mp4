@echo off
:: Включаем поддержку UTF-8 для корректного отображения текста в консоли
chcp 65001 >nul
:: Включаем режим отложенного расширения переменных (необходимо для !переменных! в циклах)
setlocal enabledelayedexpansion

:: ==========================================
:: НАСТРОЙКИ ПУТЕЙ (Убедитесь, что они верны)
:: ==========================================
set "ffmpeg_path=C:\ffmpeg\bin\ffmpeg.exe"
set "ffprobe_path=C:\ffmpeg\bin\ffprobe.exe"
set "output_root=C:\converted_files"

:: Запоминаем папку, где лежит сам скрипт (базовая папка)
set "base_dir=%CD%"

:: ==========================================
:: ОСНОВНОЙ ЦИКЛ ПОИСКА ФАЙЛОВ
:: ==========================================
:: /r ищет файлы во всех подпапках текущей директории
for /r "%base_dir%" %%f in (*.mkv *.avi *.mp4 *.m4p) do (
    
    :: Записываем полный путь к файлу
    set "full_path=%%f"
    :: Извлекаем расширение (.mkv, .mp4 и т.д.)
    set "ext=%%~xf"
    :: Извлекаем только имя файла без расширения
    set "name=%%~nf"
    
    :: --- ВЫЧИСЛЯЕМ ПУТЬ ДЛЯ СОХРАНЕНИЯ ---
    :: %%~dpf — это путь к папке текущего файла
    set "current_f_dir=%%~dpf"
    :: Вырезаем из него путь базовой папки, чтобы получить относительный путь
    set "rel_dir=!current_f_dir:%base_dir%=!"
    :: Соединяем целевую папку с относительным путем
    set "target_dir=%output_root%!rel_dir!"

    :: Создаем папку в месте назначения, если её нет (2>nul скрывает ошибки)
    if not exist "!target_dir!" mkdir "!target_dir!" 2>nul

    :: --- ЛОГИКА 1: ЕСЛИ ФАЙЛ УЖЕ MP4 ИЛИ M4P ---
    :: Мы просто копируем его "как есть" в папку назначения
    set "is_fast_copy=0"
    if /I "!ext!"==".mp4" set "is_fast_copy=1"
    if /I "!ext!"==".m4p" set "is_fast_copy=1"

    if "!is_fast_copy!"=="1" (
        echo [КОПИРОВАНИЕ] !name!!ext!
        copy /Y "%%f" "!target_dir!!name!!ext!" >nul
    ) else (
        
        :: --- ЛОГИКА 2: АНАЛИЗ АУДИО (ДЛЯ MKV И AVI) ---
        echo [АНАЛИЗ АУДИО] !name!
        
        :: Сбрасываем переменные перед проверкой нового файла
        set "codec="
        set "channels="
        
        :: Вызываем ffprobe для получения формата и количества каналов первой аудиодорожки
        for /f "tokens=1,2 delims=," %%a in ('"%ffprobe_path%" -v error -select_streams a:0 -show_entries stream^=codec_name^,channels -of csv^=p^=0 "%%f"') do (
            set "codec=%%a"
            set "channels=%%b"
        )

        :: Настройки по умолчанию: конвертация в AAC, стерео, громкость +10%
        set "a_cmd=-c:a aac -ac 2 -b:a 192k -filter:a "volume=1.1""

        :: Если аудио уже AAC и при этом Stereo (2 канала) — просто копируем поток без перекодировки
        if "!codec!"=="aac" if "!channels!"=="2" (
            echo [АУДИО OK] Копирую поток без изменений...
            set "a_cmd=-c:a copy"
        )

        :: --- ЗАПУСК КОНВЕРТАЦИИ ---
        :: -c:v copy : видеопоток копируется без перекодировки (быстро и без потерь)
        :: -c:s mov_text : преобразуем субтитры в стандарт MP4
        echo [FFMPEG] Обработка: !name!
        "%ffmpeg_path%" -i "%%f" ^
            -map 0:v? -map 0:a? -map 0:s? ^
            -c:v copy ^
            !a_cmd! ^
            -c:s mov_text ^
            -disposition:s default ^
            -y ^
            "!target_dir!!name!.mp4"
    )
)

echo.
echo ========================================
echo ВСЕ ОПЕРАЦИИ ЗАВЕРШЕНЫ УСПЕШНО
echo ========================================
pause
