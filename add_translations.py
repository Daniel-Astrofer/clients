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
    "homeFilterEmptyTitle": "Nada neste filtro",
    "homeFilterEmptyDesc": "Não há lançamentos para este filtro. Tente “Tudo” ou puxe para atualizar.",
    "homeClearFilter": "Limpar filtro",
    "homeHistoryEmptyTitle": "Histórico ainda vazio",
    "homeHistoryEmptyDesc": "Há saldo, mas nenhum lançamento na projeção local. Puxe para sincronizar com o servidor.",
    "homeSyncing": "Sincronizando extrato…",
    "homeOfflineExtract": "Offline · extrato local",
    "homeOfflineExtractDate": "Offline · extrato local · {date}",
    "@homeOfflineExtractDate": {
        "placeholders": {
            "date": {"type": "String"}
        }
    },
    "homeUpdatedDate": "{count} lançamentos · atualizado {date}",
    "@homeUpdatedDate": {
        "placeholders": {
            "count": {"type": "int"},
            "date": {"type": "String"}
        }
    }
}

keys_en = {
    "homeFilterEmptyTitle": "Nothing in this filter",
    "homeFilterEmptyDesc": "No activity found for this filter. Try “All” or pull to refresh.",
    "homeClearFilter": "Clear filter",
    "homeHistoryEmptyTitle": "History is empty",
    "homeHistoryEmptyDesc": "There is balance, but no local history. Pull to sync with server.",
    "homeSyncing": "Syncing history…",
    "homeOfflineExtract": "Offline · local history",
    "homeOfflineExtractDate": "Offline · local history · {date}",
    "@homeOfflineExtractDate": {
        "placeholders": {
            "date": {"type": "String"}
        }
    },
    "homeUpdatedDate": "{count} entries · updated {date}",
    "@homeUpdatedDate": {
        "placeholders": {
            "count": {"type": "int"},
            "date": {"type": "String"}
        }
    }
}

keys_es = {
    "homeFilterEmptyTitle": "Nada en este filtro",
    "homeFilterEmptyDesc": "No hay actividad para este filtro. Intente “Todos” o deslice para actualizar.",
    "homeClearFilter": "Limpiar filtro",
    "homeHistoryEmptyTitle": "El historial está vacío",
    "homeHistoryEmptyDesc": "Hay saldo, pero no hay historial local. Deslice para sincronizar con el servidor.",
    "homeSyncing": "Sincronizando historial…",
    "homeOfflineExtract": "Offline · historial local",
    "homeOfflineExtractDate": "Offline · historial local · {date}",
    "@homeOfflineExtractDate": {
        "placeholders": {
            "date": {"type": "String"}
        }
    },
    "homeUpdatedDate": "{count} entradas · actualizado {date}",
    "@homeUpdatedDate": {
        "placeholders": {
            "count": {"type": "int"},
            "date": {"type": "String"}
        }
    }
}

add_keys('/home/astrofer/Kerosene/frontend/lib/core/l10n/app_pt.arb', keys_pt)
add_keys('/home/astrofer/Kerosene/frontend/lib/core/l10n/app_en.arb', keys_en)
add_keys('/home/astrofer/Kerosene/frontend/lib/core/l10n/app_es.arb', keys_es)
print("Translations added!")
