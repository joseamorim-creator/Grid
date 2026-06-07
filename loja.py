#!/usr/bin/env python3
"""Aplicativo de compras em terminal."""

import json
import os
from pathlib import Path
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.prompt import Prompt, IntPrompt, Confirm
from rich.text import Text
from rich.columns import Columns
from rich import box

console = Console()

CART_FILE = Path("carrinho.json")

# ── Catálogo de produtos ────────────────────────────────────────────────────
CATALOG = [
    # Eletrônicos
    {"id": 1,  "nome": "Smartphone Pro X",     "preco": 2499.90, "cat": "Eletrônicos", "estoque": 10, "emoji": "📱"},
    {"id": 2,  "nome": "Fone Bluetooth ANC",   "preco":  349.90, "cat": "Eletrônicos", "estoque": 25, "emoji": "🎧"},
    {"id": 3,  "nome": "Smart TV 55\"",         "preco": 3199.00, "cat": "Eletrônicos", "estoque":  5, "emoji": "📺"},
    {"id": 4,  "nome": "Notebook Ultrafino",   "preco": 4799.00, "cat": "Eletrônicos", "estoque":  8, "emoji": "💻"},
    {"id": 5,  "nome": "Câmera 4K",            "preco": 1899.90, "cat": "Eletrônicos", "estoque": 12, "emoji": "📷"},
    # Roupas
    {"id": 6,  "nome": "Camiseta Premium",     "preco":   89.90, "cat": "Roupas",      "estoque": 50, "emoji": "👕"},
    {"id": 7,  "nome": "Calça Jeans Slim",     "preco":  199.90, "cat": "Roupas",      "estoque": 30, "emoji": "👖"},
    {"id": 8,  "nome": "Tênis Running",        "preco":  359.90, "cat": "Roupas",      "estoque": 20, "emoji": "👟"},
    {"id": 9,  "nome": "Jaqueta Impermeável",  "preco":  449.90, "cat": "Roupas",      "estoque": 15, "emoji": "🧥"},
    # Alimentos
    {"id": 10, "nome": "Café Especial 500g",   "preco":   54.90, "cat": "Alimentos",   "estoque": 100, "emoji": "☕"},
    {"id": 11, "nome": "Whey Protein 1kg",     "preco":  189.90, "cat": "Alimentos",   "estoque": 40, "emoji": "💪"},
    {"id": 12, "nome": "Azeite Extra Virgem",  "preco":   39.90, "cat": "Alimentos",   "estoque": 60, "emoji": "🫒"},
    # Casa
    {"id": 13, "nome": "Liquidificador 700W",  "preco":  129.90, "cat": "Casa",        "estoque": 18, "emoji": "🥤"},
    {"id": 14, "nome": "Jogo de Lençóis 300T", "preco":  249.90, "cat": "Casa",        "estoque": 22, "emoji": "🛏️"},
    {"id": 15, "nome": "Luminária LED",        "preco":   79.90, "cat": "Casa",        "estoque": 35, "emoji": "💡"},
]

# ── Carrinho ────────────────────────────────────────────────────────────────
cart: dict[int, int] = {}   # {produto_id: quantidade}


def salvar_carrinho():
    CART_FILE.write_text(json.dumps(cart))


def carregar_carrinho():
    global cart
    if CART_FILE.exists():
        cart = {int(k): v for k, v in json.loads(CART_FILE.read_text()).items()}


def produto_por_id(pid: int):
    return next((p for p in CATALOG if p["id"] == pid), None)


def total_carrinho() -> float:
    return sum(produto_por_id(pid)["preco"] * qty for pid, qty in cart.items())


def itens_carrinho() -> int:
    return sum(cart.values())


# ── UI helpers ──────────────────────────────────────────────────────────────
def cabecalho():
    os.system("clear" if os.name == "posix" else "cls")
    console.print(Panel(
        "[bold white]🛒  LOJA VIRTUAL[/bold white]\n"
        "[dim]Bem-vindo(a)! Escolha uma opção abaixo.[/dim]",
        style="bold cyan", border_style="cyan", padding=(0, 2)
    ))
    itens = itens_carrinho()
    if itens:
        console.print(
            f"  [yellow]🛒 Carrinho: {itens} item(ns)  •  "
            f"Total: [bold]R$ {total_carrinho():,.2f}[/bold][/yellow]\n"
        )


def menu_principal():
    cabecalho()
    opcoes = [
        ("1", "🏷️  Ver catálogo",      "cyan"),
        ("2", "🔍  Buscar produto",     "cyan"),
        ("3", "🛒  Ver carrinho",       "yellow"),
        ("4", "➕  Adicionar ao carrinho", "green"),
        ("5", "➖  Remover do carrinho",   "red"),
        ("6", "💳  Finalizar compra",   "bold magenta"),
        ("0", "🚪  Sair",              "dim"),
    ]
    for num, label, cor in opcoes:
        console.print(f"  [{cor}][{num}][/{cor}] {label}")
    console.print()
    return Prompt.ask("[bold]Opção[/bold]", choices=["0","1","2","3","4","5","6"])


# ── Telas ───────────────────────────────────────────────────────────────────
def tela_catalogo(produtos=None, titulo="📦 Catálogo de Produtos"):
    cabecalho()
    if produtos is None:
        produtos = CATALOG

    # Agrupar por categoria
    cats: dict[str, list] = {}
    for p in produtos:
        cats.setdefault(p["cat"], []).append(p)

    if not cats:
        console.print("[yellow]Nenhum produto encontrado.[/yellow]")
        Prompt.ask("\nPressione Enter para voltar")
        return

    for cat, itens in cats.items():
        t = Table(title=f"{cat}", box=box.ROUNDED, border_style="dim", show_header=True,
                  header_style="bold white on #1a1d35", title_style="bold cyan")
        t.add_column("ID",      style="dim",          width=4,  justify="right")
        t.add_column("",        width=3)
        t.add_column("Produto", style="bold white",   min_width=22)
        t.add_column("Preço",   style="bold green",   width=14, justify="right")
        t.add_column("Estoque", style="dim",          width=9,  justify="center")
        t.add_column("Carrinho",style="yellow",       width=9,  justify="center")

        for p in itens:
            qty = cart.get(p["id"], 0)
            est_cor = "red" if p["estoque"] == 0 else ("yellow" if p["estoque"] < 5 else "green")
            t.add_row(
                str(p["id"]),
                p["emoji"],
                p["nome"],
                f"R$ {p['preco']:,.2f}",
                f"[{est_cor}]{p['estoque']}[/{est_cor}]",
                f"[bold yellow]{qty}[/bold yellow]" if qty else "—",
            )
        console.print(t)

    Prompt.ask("\nPressione Enter para voltar")


def tela_buscar():
    cabecalho()
    console.print(Panel("[bold]🔍 Buscar Produto[/bold]", border_style="cyan", padding=(0,2)))
    termo = Prompt.ask("Digite o nome ou categoria").strip().lower()
    resultado = [p for p in CATALOG if termo in p["nome"].lower() or termo in p["cat"].lower()]
    tela_catalogo(resultado, titulo=f'🔍 Resultados para "{termo}"')


def tela_carrinho():
    cabecalho()
    if not cart:
        console.print(Panel("[yellow]Seu carrinho está vazio.[/yellow]", border_style="yellow", padding=(0,2)))
        Prompt.ask("\nPressione Enter para voltar")
        return

    t = Table(title="🛒 Seu Carrinho", box=box.ROUNDED, border_style="yellow",
              header_style="bold white on #1a1d35", title_style="bold yellow")
    t.add_column("",       width=3)
    t.add_column("Produto",style="bold white", min_width=24)
    t.add_column("Preço unit.", style="green", width=14, justify="right")
    t.add_column("Qtd",    width=6,  justify="center")
    t.add_column("Subtotal", style="bold green", width=14, justify="right")

    for pid, qty in cart.items():
        p = produto_por_id(pid)
        t.add_row(
            p["emoji"], p["nome"],
            f"R$ {p['preco']:,.2f}",
            str(qty),
            f"R$ {p['preco']*qty:,.2f}",
        )

    t.add_section()
    t.add_row("", "[bold]TOTAL[/bold]", "", f"[bold]{itens_carrinho()} itens[/bold]",
              f"[bold cyan]R$ {total_carrinho():,.2f}[/bold cyan]")
    console.print(t)
    Prompt.ask("\nPressione Enter para voltar")


def tela_adicionar():
    cabecalho()
    console.print(Panel("[bold green]➕ Adicionar Produto ao Carrinho[/bold green]",
                        border_style="green", padding=(0,2)))
    console.print("[dim]Digite 0 para cancelar[/dim]\n")

    try:
        pid = IntPrompt.ask("ID do produto")
    except (ValueError, KeyboardInterrupt):
        return

    if pid == 0:
        return

    p = produto_por_id(pid)
    if not p:
        console.print("[red]Produto não encontrado.[/red]")
        Prompt.ask("Enter para continuar")
        return

    console.print(
        f"\n  {p['emoji']} [bold]{p['nome']}[/bold]  "
        f"[green]R$ {p['preco']:,.2f}[/green]  "
        f"[dim](estoque: {p['estoque']})[/dim]"
    )

    atual = cart.get(pid, 0)
    max_qty = p["estoque"] - atual
    if max_qty <= 0:
        console.print("[red]Estoque insuficiente.[/red]")
        Prompt.ask("Enter para continuar")
        return

    try:
        qty = IntPrompt.ask(f"Quantidade (máx. {max_qty})", default=1)
    except (ValueError, KeyboardInterrupt):
        return

    qty = max(1, min(qty, max_qty))
    cart[pid] = atual + qty
    p["estoque"] -= qty
    salvar_carrinho()
    console.print(f"\n[bold green]✓ {qty}x {p['nome']} adicionado(s) ao carrinho![/bold green]")
    Prompt.ask("Enter para continuar")


def tela_remover():
    cabecalho()
    if not cart:
        console.print("[yellow]Carrinho vazio.[/yellow]")
        Prompt.ask("Enter para continuar")
        return

    console.print(Panel("[bold red]➖ Remover Produto do Carrinho[/bold red]",
                        border_style="red", padding=(0,2)))

    for pid, qty in cart.items():
        p = produto_por_id(pid)
        console.print(f"  [dim][{pid}][/dim] {p['emoji']} {p['nome']} — [yellow]{qty} un.[/yellow]")

    console.print("[dim]\nDigite 0 para cancelar[/dim]")
    try:
        pid = IntPrompt.ask("\nID do produto para remover")
    except (ValueError, KeyboardInterrupt):
        return

    if pid == 0:
        return

    if pid not in cart:
        console.print("[red]Produto não está no carrinho.[/red]")
        Prompt.ask("Enter para continuar")
        return

    p = produto_por_id(pid)
    qty_atual = cart[pid]

    try:
        qty = IntPrompt.ask(f"Quantas unidades remover? (max. {qty_atual}, 0 = tudo)", default=qty_atual)
    except (ValueError, KeyboardInterrupt):
        return

    qty = max(0, min(qty, qty_atual))
    if qty == 0 or qty >= qty_atual:
        p["estoque"] += qty_atual
        del cart[pid]
        console.print(f"[bold red]✓ {p['nome']} removido do carrinho.[/bold red]")
    else:
        cart[pid] -= qty
        p["estoque"] += qty
        console.print(f"[bold yellow]✓ {qty}x {p['nome']} removido(s).[/bold yellow]")

    salvar_carrinho()
    Prompt.ask("Enter para continuar")


def tela_checkout():
    cabecalho()
    if not cart:
        console.print("[yellow]Carrinho vazio — adicione produtos antes de finalizar.[/yellow]")
        Prompt.ask("Enter para continuar")
        return

    console.print(Panel("[bold magenta]💳 Finalizar Compra[/bold magenta]",
                        border_style="magenta", padding=(0,2)))

    tela_carrinho()

    # Dados do cliente
    cabecalho()
    console.print(Panel("[bold]📋 Dados do Pedido[/bold]", border_style="magenta", padding=(0,2)))
    nome = Prompt.ask("Seu nome")
    email = Prompt.ask("E-mail")

    # Frete
    console.print("\n[bold]🚚 Tipo de entrega:[/bold]")
    console.print("  [1] Padrão  (5–7 dias úteis) — [green]Grátis[/green]")
    console.print("  [2] Expresso (2–3 dias úteis) — [yellow]R$ 19,90[/yellow]")
    console.print("  [3] Mesmo dia               — [red]R$ 39,90[/red]")
    frete_op = Prompt.ask("Entrega", choices=["1","2","3"], default="1")
    fretes = {"1": (0, "Padrão (5-7 dias úteis)"),
              "2": (19.90, "Expresso (2-3 dias úteis)"),
              "3": (39.90, "Mesmo dia")}
    frete_val, frete_nome = fretes[frete_op]

    # Pagamento
    console.print("\n[bold]💳 Forma de pagamento:[/bold]")
    console.print("  [1] Cartão de crédito")
    console.print("  [2] PIX  [green](5% de desconto)[/green]")
    console.print("  [3] Boleto [dim](vence em 3 dias)[/dim]")
    pag = Prompt.ask("Pagamento", choices=["1","2","3"], default="1")
    pagamentos = {"1": "Cartão de crédito", "2": "PIX (5% desc.)", "3": "Boleto bancário"}

    subtotal = total_carrinho()
    desconto = subtotal * 0.05 if pag == "2" else 0
    total = subtotal - desconto + frete_val

    # Confirmação
    cabecalho()
    console.print(Panel("[bold]📄 Resumo do Pedido[/bold]", border_style="magenta", padding=(0,2)))

    t = Table(box=box.SIMPLE, show_header=False, padding=(0,1))
    t.add_column(style="dim", width=20)
    t.add_column(style="bold white")
    t.add_row("Cliente:", nome)
    t.add_row("E-mail:", email)
    t.add_row("Entrega:", frete_nome)
    t.add_row("Pagamento:", pagamentos[pag])
    t.add_section()
    t.add_row("Subtotal:", f"R$ {subtotal:,.2f}")
    if desconto:
        t.add_row("[green]Desconto PIX:[/green]", f"[green]-R$ {desconto:,.2f}[/green]")
    t.add_row("Frete:", f"R$ {frete_val:,.2f}" if frete_val else "Grátis")
    t.add_section()
    t.add_row("[bold cyan]TOTAL:[/bold cyan]", f"[bold cyan]R$ {total:,.2f}[/bold cyan]")
    console.print(t)

    if not Confirm.ask("\n[bold]Confirmar pedido?[/bold]"):
        console.print("[yellow]Pedido cancelado.[/yellow]")
        Prompt.ask("Enter para continuar")
        return

    # Sucesso
    cart.clear()
    salvar_carrinho()
    cabecalho()
    console.print(Panel(
        f"[bold green]✅  PEDIDO CONFIRMADO![/bold green]\n\n"
        f"Obrigado, [bold]{nome}[/bold]! 🎉\n"
        f"Você receberá a confirmação em [cyan]{email}[/cyan].\n\n"
        f"[dim]Total cobrado: [bold]R$ {total:,.2f}[/bold][/dim]",
        border_style="green", padding=(1, 4)
    ))
    Prompt.ask("\nPressione Enter para continuar")


# ── Loop principal ───────────────────────────────────────────────────────────
def main():
    carregar_carrinho()
    while True:
        op = menu_principal()
        if op == "1":
            tela_catalogo()
        elif op == "2":
            tela_buscar()
        elif op == "3":
            tela_carrinho()
        elif op == "4":
            tela_adicionar()
        elif op == "5":
            tela_remover()
        elif op == "6":
            tela_checkout()
        elif op == "0":
            cabecalho()
            console.print("[dim]Até logo! 👋[/dim]\n")
            break


if __name__ == "__main__":
    main()
