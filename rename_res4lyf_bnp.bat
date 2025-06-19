@echo off
rem ===========================================================
rem  full_isolate_res4lyf_bnp.bat
rem  彻底隔离 RES4LYF_BNP，与原版共存无冲突
rem ===========================================================

setlocal EnableDelayedExpansion

rem === 1) ComfyUI 根目录（按你的实际路径） ===
set COMFY_ROOT=F:\ComfyUINEW44\ComfyUI_windows_portable\ComfyUI

rem === 2) Fork 插件目录 ===
set NODE_DIR=%COMFY_ROOT%\custom_nodes\RES4LYF_BNP

rem === 3) Python 解释器 ===
set PYTHON=%COMFY_ROOT%\python_embeded\python.exe

rem === 4) 后缀设置 ===
set KEY_SUFFIX=_BNP
set DISP_SUFFIX= BNP
set FILE_PREFIX=bnp_                rem 新文件名前缀

echo.
echo ==============================================
echo  分离路径 : %NODE_DIR%
echo  Python   : %PYTHON%
echo ==============================================
echo.

pushd "%NODE_DIR%" || (echo !!! 目录不存在 & pause & exit /b)

"%PYTHON%" - <<PY
import pathlib, re, os, shutil, sys

KEY_SUFFIX      = os.environ["KEY_SUFFIX"]     # _BNP
DISP_SUFFIX     = os.environ["DISP_SUFFIX"]    #  BNP
FILE_PREFIX     = os.environ["FILE_PREFIX"]    # bnp_

root = pathlib.Path(".")

# 1) 找到所有顶层 py 文件（排除 __init__.py）
py_files = [p for p in root.glob("*.py") if p.name != "__init__.py"]
orig_names = {p.stem for p in py_files}        # e.g. {'nodes_misc', 'res4lyf'}

print(f"Renaming {len(py_files)} files with prefix '{FILE_PREFIX}' ...")

# 2) 先改文件名
rename_map = {}   # old_name -> new_name
for p in py_files:
    new_name = FILE_PREFIX + p.name            # bnp_nodes_misc.py
    p.rename(p.with_name(new_name))
    rename_map[p.stem] = FILE_PREFIX + p.stem  # nodes_misc -> bnp_nodes_misc

# 3) 处理所有 .py（包括改名后的）内容
all_py = list(root.glob("*.py"))    # 现在包括 bnp_*.py + __init__.py
key_pat   = re.compile(r'"([A-Za-z0-9_]+)"\s*:')              # "Key":
class_pat = re.compile(r'(?<=class )([A-Za-z0-9_]+)(?=\s*\()')
disp_pat  = re.compile(r'"([^"]+)"\s*:\s*"([A-Za-z0-9_]+%s)"' % KEY_SUFFIX)

# 构造内部 import 替换用正则
imports_regex = [
    (re.compile(rf'from\s+{old}\s+import'), f'from {new} import')
    for old, new in rename_map.items()
] + [
    (re.compile(rf'import\s+{old}\b'), f'import {new}')
    for old, new in rename_map.items()
]

print("Patching keys, classes, display names and internal imports ...")

for path in all_py:
    txt = path.read_text(encoding="utf-8")

    # ① 键名加后缀
    txt = key_pat.sub(lambda m: f'"{m.group(1)}{KEY_SUFFIX}":', txt)

    # ② 类名加后缀
    txt = class_pat.sub(lambda m: f"{m.group(1)}{KEY_SUFFIX}", txt)

    # ③ 显示名加“BNP”
    def _disp(m):
        disp, internal = m.groups()
        if disp.endswith(DISP_SUFFIX):
            return m.group(0)       # 已经有 BNP 就不重复
        return f'"{disp}{DISP_SUFFIX}": "{internal}"'
    txt = disp_pat.sub(_disp, txt)

    # ④ 改内部 import
    for pat, repl in imports_regex:
        txt = pat.sub(repl, txt)

    path.write_text(txt, encoding="utf-8")

print("✅ 完成所有替换！")
PY

popd

echo.
echo -----------------------------------------------------
echo  全自动隔离完成！重启 ComfyUI 后将看到：
echo    原版節點 :  ClownsharkSampler 等
echo    Fork 節點 :  ClownsharkSampler_BNP 等
echo  兩套代碼完全互不干擾。
echo -----------------------------------------------------
pause
