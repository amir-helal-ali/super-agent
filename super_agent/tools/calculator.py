"""
calculator.py - أداة الحاسبة
تقييم تعبيرات رياضية بشكل آمن - بدون eval
"""
import ast
import operator
from typing import Dict, Any


# عمليات مدعومة بشكل آمن
_OPERATORS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.FloorDiv: operator.floordiv,
    ast.Mod: operator.mod,
    ast.Pow: operator.pow,
    ast.USub: operator.neg,
    ast.UAdd: operator.pos,
}

# دوال مدعومة
_FUNCTIONS = {
    "abs": abs, "round": round, "min": min, "max": max,
    "sum": sum, "pow": pow, "int": int, "float": float,
}

# ثوابت مدعومة
_CONSTANTS = {
    "pi": 3.141592653589793,
    "e": 2.718281828459045,
}


def _safe_eval_node(node):
    """تقييم عقدة AST بشكل آمن"""
    if isinstance(node, ast.Expression):
        return _safe_eval_node(node.body)
    if isinstance(node, ast.Num):  # Python < 3.8
        return node.n
    if isinstance(node, ast.Constant):
        if isinstance(node.value, (int, float)):
            return node.value
        raise ValueError(f"ثابت غير مدعوم: {node.value}")
    if isinstance(node, ast.BinOp):
        op = _OPERATORS.get(type(node.op))
        if not op:
            raise ValueError(f"عملية غير مدعومة: {type(node.op).__name__}")
        return op(_safe_eval_node(node.left), _safe_eval_node(node.right))
    if isinstance(node, ast.UnaryOp):
        op = _OPERATORS.get(type(node.op))
        if not op:
            raise ValueError(f"عملية أحادية غير مدعومة: {type(node.op).__name__}")
        return op(_safe_eval_node(node.operand))
    if isinstance(node, ast.Call):
        if not isinstance(node.func, ast.Name):
            raise ValueError("استدعاء دالة غير مدعوم")
        func = _FUNCTIONS.get(node.func.id)
        if not func:
            raise ValueError(f"دالة غير مدعومة: {node.func.id}")
        args = [_safe_eval_node(a) for a in node.args]
        return func(*args)
    if isinstance(node, ast.Name):
        if node.id in _CONSTANTS:
            return _CONSTANTS[node.id]
        raise ValueError(f"متغير غير معروف: {node.id}")
    raise ValueError(f"نوع عقدة غير مدعوم: {type(node).__name__}")


def calculate(expression: str) -> Dict[str, Any]:
    """
    حساب تعبير رياضي بشكل آمن

    Args:
        expression: تعبير رياضي مثل "2 + 3 * 4" أو "sqrt(16)"

    Returns:
        dict يحتوي على النتيجة أو رسالة خطأ
    """
    try:
        # استبدال الدوال الشائعة
        expr = expression.replace("^", "**")
        # استبدال sqrt بـ **0.5
        expr = expr.replace("sqrt(", "(").replace(")", ")**0.5") \
                   if "sqrt(" in expr else expr

        tree = ast.parse(expr.strip(), mode="eval")
        result = _safe_eval_node(tree)

        # تنسيق النتيجة
        if isinstance(result, float):
            if result.is_integer():
                result = int(result)
            else:
                result = round(result, 10)

        return {
            "success": True,
            "expression": expression,
            "result": result,
            "formatted": f"{expression} = {result}",
        }
    except Exception as e:
        return {
            "success": False,
            "expression": expression,
            "error": str(e),
        }


# مخطط الأداة لـ LLM
TOOL_SCHEMA = {
    "name": "calculator",
    "description": "حساب تعبيرات رياضية بشكل آمن. يدعم +, -, *, /, **, %, abs, round, min, max, pi, e.",
    "parameters": {
        "type": "object",
        "properties": {
            "expression": {
                "type": "string",
                "description": "تعبير رياضي مثل: 2 + 3 * 4 أو sqrt(16) أو 2 ** 10",
            }
        },
        "required": ["expression"],
    },
}
