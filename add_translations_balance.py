import json
import sys

def add_keys(file_path, new_keys):
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    for k, v in new_keys.items():
        if k not in data:
            data[k] = v
            
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')

keys_pt = {
    "homeBalanceInternal": "Saldo Interno",
    "homeBalanceOnchain": "Saldo Onchain",
    "homeBalanceCold": "Cold wallet (na rede)",
    "homeBalanceTotal": "Saldo",
    "homeBalancePlatform": "Saldo",
    "homeBtcMarketChange": "BTC mercado {sign}{percent}% (24h)",
    "@homeBtcMarketChange": {
        "placeholders": {
            "sign": {"type": "String"},
            "percent": {"type": "String"}
        }
    },
    "homeQuoteUnavailable": "{currency} indisponível",
    "@homeQuoteUnavailable": {
        "placeholders": {
            "currency": {"type": "String"}
        }
    },
    "homeWalletInternal": "Interno",
    "homeWalletOnchain": "Onchain",
    "homeWalletCold": "Cold",
    "homeWalletPlatform": "Plataforma",
    "homeWalletTotalLabel": "Kerosene",
    "homeWalletInternalDesc": "Instantâneo (Lighting offchain)",
    "homeWalletOnchainDesc": "Auto-custódia na rede Bitcoin",
    "homeWalletColdDesc": "Monitorado (Somente leitura)",
    "homeWalletPlatformDesc": "Saldo interno (disponível instantaneamente)",
    "homeCardAvailable": "Cartão Kerosene · disponível para uso",
    "homeInternalCustody": "Interno + custódia · frio não incluso"
}

keys_en = {
    "homeBalanceInternal": "Internal balance",
    "homeBalanceOnchain": "On-chain balance",
    "homeBalanceCold": "Cold wallet (on-chain)",
    "homeBalanceTotal": "Balance",
    "homeBalancePlatform": "Balance",
    "homeBtcMarketChange": "BTC market {sign}{percent}% (24h)",
    "@homeBtcMarketChange": {
        "placeholders": {
            "sign": {"type": "String"},
            "percent": {"type": "String"}
        }
    },
    "homeQuoteUnavailable": "{currency} unavailable",
    "@homeQuoteUnavailable": {
        "placeholders": {
            "currency": {"type": "String"}
        }
    },
    "homeWalletInternal": "Internal",
    "homeWalletOnchain": "On-chain",
    "homeWalletCold": "Cold",
    "homeWalletPlatform": "Platform",
    "homeWalletTotalLabel": "Kerosene",
    "homeWalletInternalDesc": "Instant (Lighting offchain)",
    "homeWalletOnchainDesc": "Self-custody on Bitcoin network",
    "homeWalletColdDesc": "Monitored (Read only)",
    "homeWalletPlatformDesc": "Internal balance (instantly available)",
    "homeCardAvailable": "Kerosene Card · ready to use",
    "homeInternalCustody": "Internal + custody · cold not included"
}

keys_es = {
    "homeBalanceInternal": "Saldo interno",
    "homeBalanceOnchain": "Saldo on-chain",
    "homeBalanceCold": "Cold wallet (en cadena)",
    "homeBalanceTotal": "Saldo",
    "homeBalancePlatform": "Saldo",
    "homeBtcMarketChange": "BTC mercado {sign}{percent}% (24h)",
    "@homeBtcMarketChange": {
        "placeholders": {
            "sign": {"type": "String"},
            "percent": {"type": "String"}
        }
    },
    "homeQuoteUnavailable": "{currency} no disponible",
    "@homeQuoteUnavailable": {
        "placeholders": {
            "currency": {"type": "String"}
        }
    },
    "homeWalletInternal": "Interno",
    "homeWalletOnchain": "On-chain",
    "homeWalletCold": "Cold",
    "homeWalletPlatform": "Plataforma",
    "homeWalletTotalLabel": "Kerosene",
    "homeWalletInternalDesc": "Instantáneo (Lighting offchain)",
    "homeWalletOnchainDesc": "Auto-custodia en la red Bitcoin",
    "homeWalletColdDesc": "Monitoreado (Solo lectura)",
    "homeWalletPlatformDesc": "Saldo interno (disponible al instante)",
    "homeCardAvailable": "Tarjeta Kerosene · lista para usar",
    "homeInternalCustody": "Interno + custodia · frío no incluido"
}

add_keys('/home/astrofer/Kerosene/frontend/lib/core/l10n/app_pt.arb', keys_pt)
add_keys('/home/astrofer/Kerosene/frontend/lib/core/l10n/app_en.arb', keys_en)
add_keys('/home/astrofer/Kerosene/frontend/lib/core/l10n/app_es.arb', keys_es)
print("Translations added!")
