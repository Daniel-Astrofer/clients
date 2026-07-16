import json

def add_keys(file_path, new_keys):
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    for k, v in new_keys.items():
        if k not in data:
            data[k] = v
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')

k_pt = {
    "homeOnchainTab": "Onchain",
    "homeColdTab": "Frio",
    "homeOnchainWalletCardTitle": "Carteira Onchain",
    "homeStatementAction": "Ir para extrato"
}
k_en = {
    "homeOnchainTab": "On-chain",
    "homeColdTab": "Cold",
    "homeOnchainWalletCardTitle": "On-chain wallet",
    "homeStatementAction": "Go to statement"
}
k_es = {
    "homeOnchainTab": "On-chain",
    "homeColdTab": "Frío",
    "homeOnchainWalletCardTitle": "Cartera on-chain",
    "homeStatementAction": "Ir al extracto"
}

add_keys('/home/astrofer/Kerosene/frontend/lib/core/l10n/app_pt.arb', k_pt)
add_keys('/home/astrofer/Kerosene/frontend/lib/core/l10n/app_en.arb', k_en)
add_keys('/home/astrofer/Kerosene/frontend/lib/core/l10n/app_es.arb', k_es)
