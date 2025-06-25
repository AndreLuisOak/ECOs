<template>
  <MainPage>
    <section class="content" id="saude">
      <v-btn 
        v-if="(modelosSelecionadosComputado && modelosSelecionadosComputado.length > 1) && !relatorioGerado"
        @click="gerarRelatorio()" 
        color="primary"
      >
        Gerar relatório de saúde e qualidade
      </v-btn>

      <v-btn v-else-if="relatorioGerado" @click="limpar" color="error">
        Voltar
      </v-btn>

      <h1 v-else>Relatório de saúde e qualidade de ECOS</h1>
      
      <v-pagination 
        v-if="!relatorioGerado" 
        class="my-4" 
        v-model="page" 
        :length="pageSize" 
        @input="pageChange"
      ></v-pagination>

      <p v-if="!relatorioGerado">Selecione pelo menos 2 modelos para gerar análise</p>

      <div class="container">
        <div v-if="relatorioGerado && modelosAnalisados.length">
          <v-expansion-panels multiple>
            <v-expansion-panel v-for="(modelo, index) in modelosAnalisados" :key="index">
              <v-expansion-panel-header>
                <h2>{{ index + 1 + " - " + modelo.titulo }}</h2>
              </v-expansion-panel-header>
              
              <v-expansion-panel-content>
                <div class="saude-modelo-imagem">
                  <img :src="getPreview(modelo.codigo)" alt="preview" />
                </div>
                
                <div class="saude-modelo-tabela">
                  <v-data-table
                    :headers="headers"
                    :items="[
                      ...modelo.metricas,
                      ...(index > 0 ? [
                        { 
                          nome: 'Retenção de Atores', 
                          valor: modelo.retencaoAtores.taxaRetencao + '%', 
                          classificacao: getClassificacaoRetencao(modelo.retencaoAtores.taxaRetencao) 
                        },
                        { 
                          nome: 'Capacidade de Regeneração', 
                          valor: modelo.retencaoAtores.capacidadeRegeneracao + '%', 
                          classificacao: getClassificacaoRegeneracao(modelo.retencaoAtores.capacidadeRegeneracao) 
                        }
                      ] : [])
                    ]"
                    hide-default-footer
                    class="elevation-1"
                  >
                    <template v-slot:item.valor="{ item }">
                      <v-chip :color="getColorMetrica(item.valor)" dark>
                        {{
                          (typeof item.valor === 'number' && !isNaN(item.valor))
                            ? item.valor.toFixed(2)
                            : (
                                (!isNaN(parseFloat(item.valor)) && item.valor !== null && item.valor !== undefined && item.valor !== '' && item.valor !== '-')
                                  ? parseFloat(item.valor).toFixed(2)
                                  : item.valor
                              )
                        }}
                      </v-chip>
                    </template>
                  </v-data-table>
                </div>

                <div class="saude-modelo-chart">
                  <BarChart 
                    :options="chartOptionsRetencao" 
                    :data="formatChartDataRetencao(modelo.retencaoAtores)"
                  />
                </div>
              </v-expansion-panel-content>
            </v-expansion-panel>

            <v-expansion-panel v-if="modelosAnalisados.length > 1">
              <v-expansion-panel-header>
                <h2>Comparação entre os Modelos Analisados</h2>
              </v-expansion-panel-header>
              <v-expansion-panel-content>
                <div class="comparacao-componentes">
                  <h3>Quantidade de Componentes por Tipo</h3>
                  <BarChart
                    :options="componentesChartOptions"
                    :data="componentesPorTipoData"
                    type="ColumnChart"
                  />
                </div>

                <BarChart
                  :options="{
                    title: 'Quantidade de Componentes entre as Versões',
                    chartArea: { width: '70%' },
                    height: 500,
                    legend: { position: 'right' }
                  }"
                  :type="'ColumnChart'"
                  :data="graficoQuantidadeComponentes"
                />

                <BarChart 
                  :options="{ 
                    title: 'Quantidade de Componentes e Relacionamentos',
                    chartArea: { width: '70%' },
                    height: 500,
                    legend: { position: 'right' }
                  }" 
                  :type="'ColumnChart'"
                  :data="compararComponentesERelacionamentos" 
                />

                <div v-for="grafico in graficosComparacao" :key="grafico.key" class="my-6">
                  <BarChart
                    :options="{
                      title: grafico.label,
                      height: 400,
                      chartArea: { width: '70%' },
                      legend: { position: 'right' }
                    }"
                    :data="grafico.data"
                    type="ColumnChart"
                  />
                </div>

                <v-chip class="ma-2 ml-0" color="red" label text-color="white">
                  <v-icon left>mdi-table</v-icon>
                  Comparação Geral de Métricas
                </v-chip>

                <v-data-table
                  :headers="[
                    { text: 'Métrica', value: 'metrica' },
                    ...modelosAnalisados.map((m, idx) => ({ text: m.titulo || `Modelo ${idx + 1}`, value: `modelo${idx + 1}` }))
                  ]"
                  :items="metricasComparadas"
                  hide-default-footer
                  class="elevation-1 mb-7"
                >
                  <template v-slot:item.valor="{ item }">
                    <v-chip>{{ item.valor }}</v-chip>
                  </template>
                </v-data-table>

                <v-chip class="ma-2 ml-0" color="red" label text-color="white">
                  <v-icon left>mdi-table</v-icon>
                  Métricas Quantitativas
                </v-chip>
                <v-data-table
                  :headers="[
                  { text: 'Métrica', value: 'metrica' },
                  ...modelosAnalisados.map((m, idx) => ({ text: m.titulo || `Modelo ${idx + 1}`, value: `modelo${idx + 1}` }))
                ]"
                :items="metricasQuantitativas"
                hide-default-footer
                class="elevation-1 mb-7">
                  <template v-slot:item.valor="{ item }">
                    <v-chip>{{ item.valor }}</v-chip>
                  </template>
                </v-data-table>
              </v-expansion-panel-content>
            </v-expansion-panel>
          </v-expansion-panels>
        </div>

        <v-item-group v-else>
          <v-container>
            <v-row alignIte="center">
              <v-col v-for="modelo in modelos" :key="modelo.codigo">
                <v-card class="mx-auto d-flex flex-column align-center" max-width="350" min-width="350">
                  <v-checkbox v-model="modelosChecked" :value="modelo.codigo"></v-checkbox>
                  <v-item>
                    <CardModelo :modelo="modelo" :canEdit="false" :refresh="getModelos" />
                  </v-item>
                  <v-checkbox v-model="modelosChecked" :value="modelo.codigo"></v-checkbox>
                </v-card>
              </v-col>
            </v-row>
          </v-container>
        </v-item-group>
      </div>
    </section>
  </MainPage>
</template>

<script>
import { services } from "../services";
import MainPage from "../components/MainPage.vue";
import CardModelo from "../components/CardModelo.vue";
import BarChart from "../components/Bar.vue";

  function identificarKeystone(modeloData) {
    const regex = /<mxCell[^>]*id="(\d+)"[^>]*tipo\s*=\s*["']?empresa["']?/gi;
    const match = regex.exec(modeloData);
    return match ? match[1] : null;
  }

  function extrairRelacoes(modeloData) {
  const regex = /<mxCell[^>]*edge="1"[^>]*source="(\d+)"[^>]*target="(\d+)"[^>]*>/gi;
  const relacoes = [];
  let match;
  while ((match = regex.exec(modeloData)) !== null) {
    relacoes.push({ origem: match[1], destino: match[2] });
  }
  return relacoes;
  }

  function calcularCentralidade(keystoneID, relacoes = [], nAtores) {
    if (!keystoneID || nAtores <= 1) return 0;
    if (!Array.isArray(relacoes)) relacoes = [];

    const conexoesDiretas = relacoes.filter(rel => 
        rel.origem === keystoneID || rel.destino === keystoneID
    ).length;
    const centralidade = (conexoesDiretas / Math.max(1, nAtores - 1)) * 100;
    return parseFloat(Math.min(centralidade, 100).toFixed(2));
  }

  function calcularDensidade(nRelacionamentos, nAtores) {
    if (nAtores <= 1) return 0;
    const maxRelacionamentos = nAtores * (nAtores - 1) / 2;
    return parseFloat((nRelacionamentos / maxRelacionamentos).toFixed(4));
  }

  function calcularModularidade(nRelacionamentos, nAtores) {
    if (nAtores <= 1) return 0;
    const nMax = nAtores * (nAtores - 1) / 2;
    return parseFloat((1 - (nRelacionamentos / nMax)).toFixed(2));
  }

  function extrairAtores(modeloData) {
  const regex = /<mxCell[^>]*id="(\d+)"[^>]*vertex="1"[^>]*>/gi;
  const atores = new Set();
  let match;
  while ((match = regex.exec(modeloData)) !== null) {
    atores.add(match[1]);
  }
  return atores;
  }

  function extrairFluxos(modeloData) {
  const regexFluxos = /\b([\w]+)\s*:\s*\d+\b/g;
  const tiposFluxos = new Set();
  let match;
  while ((match = regexFluxos.exec(modeloData)) !== null) {
    tiposFluxos.add(match[1]);
  }
  return tiposFluxos;
  }

  function contarRelacionamentos(modeloData) {
    return (xml.match(/<mxCell[^>]*edge="1"/g) || []).length;
  }

  function calcularAtividadeComunidade(nElementosAlterados, nElementosTotais) {
    if (nElementosTotais === 0) return 0;
    return parseFloat((nElementosAlterados / nElementosTotais).toFixed(2));
  }

  function calcularReusabilidade(setV1, setV2) {
    const componentesReutilizados = [...setV1].filter(c => setV2.has(c)).length;
    const componentesUnicos = new Set([...setV1, ...setV2]).size;
    return componentesUnicos > 0 ? parseFloat((componentesReutilizados / componentesUnicos).toFixed(2)) : 0;
  }

  function calcularCrescimentoAtores(setV1, setV2) {
    const novos = [...setV2].filter(ator => !setV1.has(ator)).length;
    const totalAntigo = setV1.size || 1;
    return Math.min(parseFloat((novos / totalAntigo).toFixed(2)), 2.00);
  }

  function calcularEstabilidadeDependencias(relV1, relV2) {
    if (relV1.length === 0 && relV2.length === 0) return 1.00;
    if (relV1.length === 0) return 0.00;

    const relacoesV1 = new Set(relV1.map(r => `${r.origem}-${r.destino}`));
    const relacoesV2 = new Set(relV2.map(r => `${r.origem}-${r.destino}`));

    const comuns = [...relacoesV1].filter(r => relacoesV2.has(r)).length;
    return parseFloat((comuns / relacoesV1.size).toFixed(2));
  }

  function calcularDiferencaAbsoluta(setV1, setV2) {
    return Math.abs(setV2.size - setV1.size);
  }

  function calcularVariacaoRelacionamentos(n1, n2) {
    if (n1 === 0 && n2 === 0) return 0;
    if (n1 === 0) return 100;

    const variacao = (n2 - n1) / n1;
    return parseFloat((variacao * 100).toFixed(1));
  }

  function calcularVariedadeAplicacoes(modeloData) {
    const tipos = new Set();
    const regex = /<mxCell[^>]*tipo\s*=\s*["']?([^"']+)["']?/gi;
    let match;
    
    while ((match = regex.exec(modeloData)) !== null) {
        if (!['empresa', 'relacao'].includes(match[1].toLowerCase())) {
            tipos.add(match[1]);
        }
    }
    return tipos.size;
  }

  async function analisarModeloCompleto(modeloData) {
    const atores = extrairAtores(modeloData);
    const relacoes = extrairRelacoes(modeloData);
    const variedade = calcularVariedadeAplicacoes(modeloData);

    return {
      atores: {
        total: atores.size,
        mapa: atores
      },
      relacionamentos: {
        total: relacoes.length,
        lista: relacoes
      },
      keystones: {
        ids: [identificarKeystone(modeloData)].filter(Boolean)
      },
      metricas: {
        variedade,
        centralidade: calcularCentralidade(identificarKeystone(modeloData), relacoes, atores.size),
        densidade: calcularDensidade(relacoes.length, atores.size),
        modularidade: calcularModularidade(atores.size, relacoes.length)
      }
    };
  }

  function occurrences(str, subStr) {
  if (!str || !subStr) return 0;
  return (str.match(new RegExp(subStr, 'g')) || []).length;
  }

  export default {
    name: "Saude",
    components: {
      MainPage,
      CardModelo,
      BarChart
    },
    inject: ['getLanguage'],
    data() {
      return {
        modelos: [],
        modelosChecked: [],
        modelosAnalisados: [],
        relatorioGerado: false,
        page: 1,
        pageSize: 1,
        type: 'ColumnChart',
        options: {
          chartArea: { width: '80%' },
          hAxis: { title: 'Modelos', minValue: 0 },
          vAxis: { title: 'Valor'},
          width: 900,
          height: 600,
          legend: { position: 'none' },
        },
        headers: [
          { text: 'Métrica', value: 'nome' },
          { text: 'Valor', value: 'valor' },
          { text: 'Classificação', value: 'classificacao' }
        ],
        headersComparacao: [
          { text: 'Versão', value: 'versao' },
          { text: 'Atores Atuais', value: 'atoresAtuais' },
          { text: 'Atores Retidos', value: 'atoresRetidos' },
          { text: 'Taxa de Retenção', value: 'taxaRetencao' },
          { text: 'Taxa de Lançamento', value: 'taxaLancamento' },
          { text: 'Variedade de aplicações', value: 'variedadeAplicacoes' },
          { text: 'Atividade da Comunidade', value: 'atividadeComunidade' },
          { text: 'Modularidade', value: 'modularidade' },
          { text: 'Reusabilidade', value: 'reusabilidade' },
          { text: 'Crescimento de Atores', value: 'crescimentoAtores' },
          { text: 'Estabilidade de Dependências', value: 'estabilidadeDependencias' },
          { text: 'Variação Relacionamentos (%)', value: 'variacaoRelacionamentos' },
          { text: 'Diferença Absoluta Componentes', value: 'diferencaAbsolutaComponentes' },
          { text: 'Variação', value: 'variacao' }
        ],
        headersQuantitativas: [
          { text: 'Métrica', value: 'titulo' },
          { text: 'Valor', value: 'valor' },
        ],
        chartOptionsRetencao: {
          title: 'Retenção de Atores',
          chartArea: { width: '70%' },
          hAxis: {
            title: 'Porcentagem',
            minValue: 0,
            maxValue: 100
          },
          vAxis: {
            title: 'Métrica'
          },
          width: '100%',
          height: 300,
          legend: { position: 'none' }
        },
        componentesChartOptions: {
          title: 'Comparação numérica de componentes por tipo',
          chartArea: { width: '70%' },
          height: 400,
          legend: { position: 'right' },
          colors: ['#4285F4', '#EA4335', '#FBBC05', '#34A853', '#673AB7', '#FF5722', '#607D8B'],
          hAxis: {
            title: 'Tipos de Componentes',
          },
          vAxis: {
            title: 'Quantidade',
            minValue: 0
          }
        }
      };
    },
    computed: {
      language() {
        return this.getLanguage();
      },
      modelosSelecionadosComputado() {
        return this.modelosChecked || [];
      },
      dadosComparacaoRetencao() {
        if (this.modelosAnalisados.length < 2) return [];
        const comparacoes = [];

        for (let i = 1; i < this.modelosAnalisados.length; i++) {
          const atual = this.modelosAnalisados[i];
          const anterior = this.modelosAnalisados[i-1];

          const setAnterior = anterior.retencaoAtores.atoresAtuaisSet;
          const setAtual = atual.retencaoAtores.atoresAtuaisSet;
          const relAnterior = anterior.relacoes || [];
          const relAtual = atual.relacoes || [];

          const reusabilidade = calcularReusabilidade(setAnterior, setAtual);


          const crescimentoAtores = `${(calcularCrescimentoAtores(setAnterior, setAtual) * 100).toFixed(1)}%`;
          const estabilidadeDependencias = `${(calcularEstabilidadeDependencias(relAnterior, relAtual) * 100).toFixed(1)}%`;
          const variacaoRelacionamentos = `${calcularVariacaoRelacionamentos(anterior.nRelacionamentos, atual.nRelacionamentos)}%`;
          const diferencaAbsolutaComponentes = calcularDiferencaAbsoluta(setAnterior, setAtual);


          const variacao = atual.retencaoAtores.taxaRetencao - anterior.retencaoAtores.taxaRetencao;
          const elementosAlterados = Math.abs(atual.retencaoAtores.atoresAtuais - anterior.retencaoAtores.atoresAtuais);
          const atividadeComunidade = calcularAtividadeComunidade(elementosAlterados, atual.retencaoAtores.atoresAtuais);

          const variedadeAplicacoes = calcularVariedadeAplicacoes(atual.modeloData);

          comparacoes.push({
            versao: `${anterior.titulo} → ${atual.titulo}`,
            atoresAnteriores: anterior.retencaoAtores.atoresAnteriores,
            atoresAtuais: atual.retencaoAtores.atoresAtuais,
            atoresRetidos: atual.retencaoAtores.atoresRetidos,
            taxaRetencao: atual.retencaoAtores.taxaRetencao + '%',
            taxaLancamento: atual.retencaoAtores.taxaLancamento + '%',
            atividadeComunidade: (atividadeComunidade * 100).toFixed(1) + '%',
            modularidade: calcularModularidade(atual.nAtores, atual.nRelacionamentos).toFixed(2),
            reusabilidade: (reusabilidade * 100).toFixed(1) + '%',
            variacao: variacao.toFixed(2),
            crescimentoAtores,
            estabilidadeDependencias,
            variacaoRelacionamentos,
            diferencaAbsolutaComponentes,
            variedadeAplicacoes,
          });
        }
        return comparacoes;
      },
      modelosFinalComparacao() {
        return [['Modelo', 'Componentes', { role: 'annotation', type: 'string' }],
          ...this.modelosAnalisados.map(modelo => [
            modelo.titulo,
            modelo.nAtores || 0,
            String(modelo.nAtores || 0)
          ])
        ];
      },
      compararRelacionamentos() {
        return [['Modelo', 'Relacionamentos', { role: 'annotation', type: 'string' }],
          ...this.modelosAnalisados.map(modelo => [
            modelo.titulo,
            modelo.nRelacionamentos || 0,
            String(modelo.nRelacionamentos || 0)
          ])
        ];
      },
      diferencaNumerica() {
        if (this.modelosAnalisados.length < 2) return [];
        const anterior = this.modelosAnalisados[0];
        const atual = this.modelosAnalisados[this.modelosAnalisados.length - 1];
        return [['Métrica', 'Diferença', { role: 'annotation', type: 'string' }],
          ['Atores', atual.nAtores - anterior.nAtores, String(atual.nAtores - anterior.nAtores)],
          ['Relacionamentos', atual.nRelacionamentos - anterior.nRelacionamentos, String(atual.nRelacionamentos - anterior.nRelacionamentos)]
        ];
      },
      modelosFinalCompararPercent() {
        return [
          ['Modelo', 'Percentual (%)', { role: 'annotation', type: 'string' }],
          ...this.modelosAnalisados.map(modelo => [
            modelo.titulo,
            parseFloat((modelo.nAtores / (this.modelosAnalisados[0]?.nAtores || 1) * 100).toFixed(2)),
            (modelo.nAtores / (this.modelosAnalisados[0]?.nAtores || 1) * 100).toFixed(2) + '%'
          ])
        ];
      },

      graficoQuantidadeComponentes() {
        return [
          ['Modelo', 'Componentes', { role: 'annotation', type: 'string' }],
          ...this.modelosAnalisados.map(m => [
            m.titulo,
            m.nAtores || m.total || 0,
            String(m.nAtores || m.total || 0)
          ])
        ];
      },

      graficosComparativos() {
        const metricas = [
          { key: 'atoresRetidos', label: 'Atores Retidos' },
          { key: 'taxaRetencao', label: 'Taxa de Retenção (%)' },
          { key: 'taxaLancamento', label: 'Taxa de Lançamento (%)' },
          { key: 'variedadeAplicacoes', label: 'Variedade de aplicações' },
          { key: 'atividadeComunidade', label: 'Atividade da Comunidade' },
          { key: 'modularidade', label: 'Modularidade' },
          { key: 'reusabilidade', label: 'Reusabilidade' },
          { key: 'crescimentoAtores', label: 'Crescimento de Atores' },
          { key: 'estabilidadeDependencias', label: 'Estabilidade de Dependências' },
          { key: 'variacaoRelacionamentos', label: 'Variação Relacionamentos (%)' },
          { key: 'diferencaAbsolutaComponentes', label: 'Diferença Absoluta Componentes' },
          { key: 'variacao', label: 'Variação' }
        ];

        return metricas.map(metrica => {
          const data = [
            ['Versão', metrica.label, { role: 'annotation', type: 'string' }],
            ...this.dadosComparacaoRetencao.map((item, idx) => {
              let valor = item[metrica.key];
              if (valor === undefined && this.modelosAnalisados[idx + 1]) {
                valor = this.modelosAnalisadas[idx + 1][metrica.key] ||
                        this.modelosAnalisadas[idx + 1].metricasCalculo?.[metrica.key] ||
                        0;
              }
              if (typeof valor === 'string') valor = valor.replace('%', '');
              valor = parseFloat(valor);
              if (isNaN(valor)) valor = 0;
              return [item.versao || `Versão ${idx + 1}`, valor, String(valor)];
            })
          ];
          return {
            key: metrica.key,
            label: metrica.label,
            data
          };
        });
      },
      metricasQuantitativas() {
        if (this.modelosAnalisados.length < 2) return [];
          const metricas = [
            { key: 'nAtores', label: 'Total de Componentes' },
            { key: 'nRelacionamentos', label: 'Total de Relacionamentos' },
            { key: 'modularidade', label: 'Modularidade' },
            { key: 'centralidade', label: 'Centralidade do Keystone (%)' },
            { key: 'densidade', label: 'Densidade da Rede' },
          ];
          return metricas.map(m => {
          const row = { metrica: m.label };
          this.modelosAnalisados.forEach((modelo, idx) => {
            let valor = modelo[m.key] ?? modelo.analise?.metricas?.[m.key] ?? '-';
            if (typeof valor === 'number' && !Number.isInteger(valor)) {
              valor = valor.toFixed(2);
            }
            row[`modelo${idx + 1}`] = valor;
          });
          return row;
        });
      },

metricasComparadas() {
  if (this.modelosAnalisados.length < 1) return [];
  const metricas = [
    { key: 'atoresRetidos', label: 'Atores Retidos', campoModelo: 'atoresRetidos' },
    { key: 'taxaRetencao', label: 'Taxa de Retenção (%)', campoModelo: 'taxaRetencao' },
    { key: 'taxaLancamento', label: 'Taxa de Lançamento (%)', campoModelo: 'taxaLancamento' },
    { key: 'variedadeAplicacoes', label: 'Variedade de aplicações', campoModelo: 'variedadeAplicacoes' },
    { key: 'atividadeComunidade', label: 'Atividade da Comunidade', campoModelo: 'atividadeComunidade' },
    { key: 'modularidade', label: 'Modularidade', campoModelo: 'modularidade' },
    { key: 'reusabilidade', label: 'Reusabilidade', campoModelo: 'reusabilidade' },
    { key: 'crescimentoAtores', label: 'Crescimento de Atores', campoModelo: 'crescimentoAtores' },
    { key: 'estabilidadeDependencias', label: 'Estabilidade de Dependências', campoModelo: 'estabilidadeDependencias' },
    { key: 'variacaoRelacionamentos', label: 'Variação Relacionamentos (%)', campoModelo: 'variacaoRelacionamentos' }
  ];
  const rowCount = this.modelosAnalisados.length;
  return metricas.map(m => {
    const row = { metrica: m.label };
    let valorModelo1 = this.modelosAnalisados[0][m.campoModelo];
    if (valorModelo1 === undefined && this.modelosAnalisados[0].metricas) {
      const metricaObj = this.modelosAnalisados[0].metricas.find(obj =>
        obj.nome?.toLowerCase().includes(m.label.toLowerCase())
      );
      valorModelo1 = metricaObj?.valor;
    }
    if (valorModelo1 === undefined || valorModelo1 === null) valorModelo1 = '-';
    row['modelo1'] = valorModelo1;
    for (let i = 1; i < rowCount; i++) {
      let valor = this.dadosComparacaoRetencao[i - 1]?.[m.key];
      if (valor === undefined || valor === null) valor = '-';
      row[`modelo${i + 1}`] = valor;
    }
    return row;
  });
},

tabelaComparacaoComponentes() {
  const inicial = this.modelosAnalisados[0];
  const atual = this.modelosAnalisados.at(-1);
  if (!inicial || !atual) return [];

  return [
    { metrica: 'Variação no número de componentes', valor: ((atual.nAtores || 0) - (inicial.nAtores || 0)).toFixed(2) },
    { metrica: 'Variação percentual de relacionamentos', valor: (((atual.nRelacionamentos - inicial.nRelacionamentos) / (inicial.nRelacionamentos || 1)) * 100).toFixed(2) + '%' },
    { metrica: 'Média de componentes', valor: (((atual.nAtores + inicial.nAtores) / 2).toFixed(2)) },
    { metrica: 'Média de relacionamentos', valor: (((atual.nRelacionamentos + inicial.nRelacionamentos) / 2).toFixed(2)) }
  ];
},
      graficosComparacao() {
        const metricas = [
          { key: 'taxaRetencao', label: 'Taxa de Retenção (%)' },
          { key: 'taxaLancamento', label: 'Taxa de Lançamento (%)' },
          { key: 'variedadeAplicacoes', label: 'Variedade de Aplicações' },
          { key: 'atividadeComunidade', label: 'Atividade da Comunidade (%)' },
          { key: 'modularidade', label: 'Modularidade' },
          { key: 'reusabilidade', label: 'Reusabilidade (%)' },
          { key: 'crescimentoAtores', label: 'Crescimento de Atores (%)' },
          { key: 'estabilidadeDependencias', label: 'Estabilidade de Dependências (%)' },
          { key: 'variacaoRelacionamentos', label: 'Variação Relacionamentos (%)' },
          { key: 'diferencaAbsolutaComponentes', label: 'Diferença Absoluta Componentes' },
        ];

        return metricas.map(metrica => {
          const data = [
            ['Modelo', metrica.label, { role: 'annotation', type: 'string' }],
            ...this.dadosComparacaoRetencao.map((item, idx) => {
              let valor = item[metrica.key];
              if (typeof valor === 'string') valor = valor.replace('%', '');
              valor = parseFloat(valor);
              if (isNaN(valor)) valor = 0;
              return [item.versao || `Versão ${idx + 1}`, valor, String(valor)];
            })
          ];
          return {
            key: metrica.key,
            label: metrica.label,
            data
          };
        });
      },

      componentesPorTipoData() {
  if (!this.modelosAnalisados || this.modelosAnalisados.length < 1) return [];
  
  const tipos = [
    'Empresa de Interesse',
    'Fornecedor',
    'Cliente',
    'Cliente do Cliente',
    'Intermediário',
    'Agregador',
    'Relacionamentos'
  ];

  const header = ['Componentes', ...this.modelosAnalisados.map(m => m.titulo)];
  const data = [header];

  tipos.forEach(tipo => {
  const row = [tipo];
  this.modelosAnalisados.forEach(modelo => {
    if (tipo === 'Relacionamentos') {
      row.push(modelo.nRelacionamentos || 0);
    } else {
      const valor = modelo.componentesPorTipo?.[tipo] || 0;
      row.push(valor);
    }
  });
  data.push(row);
});
  
  return data;
},
    },
    methods: {
      compararComponentesERelacionamentos(){
          return [];
      },
      classificar(valor, limites, classificacoes) {
        for (let i = 0; i < limites.length; i++) {
          if (valor >= limites[i]) return classificacoes[i];
        }
        return classificacoes[classificacoes.length - 1];
      },
      async gerarRelatorio() {
        await this.analisarModelos();
        this.relatorioGerado = true;
      },
      limpar() {
        this.relatorioGerado = false;
        this.modelosChecked = [];
        this.modelosAnalisados = [];
      },
      getModelos(props = { size: 6 }) {
        services.models.list(props)
          .then((res) => {
            this.modelos = res.data.content;
            this.pageSize = res.data.totalPages;
          })
          .catch(() => {
            this.$toast.error(this.language.messages.loadErro);
          });
      },
      pageChange(page) {
        this.getModelos({ size: 6, page: page - 1 });
      },
      getPreview(codigo) {
        return services.models.preview(codigo);
      },
      getColorMetrica(valor) {
        if (typeof valor === 'string' && valor.includes('%')) {
          const num = parseFloat(valor);
          if (num >= 70) return 'green';
          if (num >= 40) return 'orange';
          return 'red';
        }
        return 'primary';
      },
      getColorVariacao(valor) {
        const num = parseFloat(valor);
        if (num > 0) return 'green';
        if (num < 0) return 'red';
        return 'blue';
      },
      getClassificacaoRetencao(taxa) {
        return this.classificar(taxa, [70, 50, 30], ['Excelente', 'Boa', 'Regular', 'Baixa']);
      },
      getClassificacaoRegeneracao(taxa) {
        return this.classificar(taxa, [70, 40], ['Alta', 'Média', 'Baixa']);
      },
      formatChartDataRetencao(dadosRetencao) {
        return [
          ['Métrica', 'Valor'],
          ['Taxa de Retenção', dadosRetencao.taxaRetencao]
        ];
      },
      async analisarModelos() {
        this.modelosAnalisados = [];

        const modelosOrdenados = [...this.modelosChecked]
          .sort((a, b) => {
            const modeloA = this.modelos.find(m => m.codigo === a);
            const modeloB = this.modelos.find(m => m.codigo === b);
            return new Date(modeloA.dataCriacao) - new Date(modeloB.dataCriacao);
          });

        for (let i = 0; i < modelosOrdenados.length; i++) {
          const id = modelosOrdenados[i];
          const resposta = await services.models.get(id);
          const { data: atualModelo } = await services.models.getModel(id);

          const modeloData = resposta.data;

          const analise = await analisarModeloCompleto(modeloData);

          const atoresAtuais = extrairAtores(modeloData);
          const nAtores = analise.atores.total;
          const relacoes = analise.relacionamentos.lista;
          const nRelacionamentos = analise.relacionamentos.total;
          const variedade = analise.metricas.variedade;
          const keystoneId = analise.keystones.ids[0] || null;
          const centralidadeKeystone = analise.metricas.centralidade;
          const densidade = analise.metricas.densidade;
          const modularidade = analise.metricas.modularidade;

          let retencaoAtores = {
            atoresAnteriores: 0,
            atoresAtuais: nAtores,
            atoresRetidos: 0,
            taxaRetencao: 0,
            capacidadeRegeneracao: 0,
            taxaLancamento: 0,
            atoresAtuaisSet: atoresAtuais
          };

          if (i > 0) {
            const modeloAnterior = this.modelosAnalisados[i - 1];
            const atoresAnteriores = modeloAnterior.retencaoAtores.atoresAtuais;
            const atoresRetidos = [...atoresAtuais].filter(ator =>
              modeloAnterior.retencaoAtores.atoresAtuaisSet.has(ator)
            ).length;

            retencaoAtores = {
              ...retencaoAtores,
              atoresAnteriores,
              atoresRetidos,
              taxaRetencao: this.calcularRetencao(atoresAnteriores, atoresRetidos)
            };

            const atoresRemovidos = atoresAnteriores - atoresRetidos;
            const atoresAdicionados = nAtores - atoresRetidos;
            if (atoresRemovidos > 0) {
              retencaoAtores.capacidadeRegeneracao = parseFloat((
                (Math.min(atoresRemovidos, atoresAdicionados) / atoresRemovidos) * 100
              ).toFixed(2));
            } else{
              retencaoAtores.capacidadeRegeneracao = 0;
            }

            const componentesAnteriores = modeloAnterior.retencaoAtores.atoresAtuaisSet;
            const novosComponentes = [...atoresAtuais].filter(comp => !componentesAnteriores.has(comp));
            if (nAtores > 0) {
              retencaoAtores.taxaLancamento = parseFloat(
                (novosComponentes.length / nAtores * 100).toFixed(2)
              );
            }
          }

          const metricas = [
            { nome: 'Total de Atores', valor: nAtores, classificacao: '' },
            { nome: 'Interdependência', valor: nAtores > 0 ? (nRelacionamentos / nAtores).toFixed(2) : 0, classificacao: '' },
            { nome: 'Variedade de Aplicações', valor: variedade, classificacao: this.classificar(variedade, [6, 3], ['Alta', 'Média', 'Baixa']) },
            { nome: 'Centralidade do Keystone', valor: `${centralidadeKeystone}%`, classificacao: this.classificar(centralidadeKeystone, [70, 40], ['Alta', 'Média', 'Baixa']) },
            { nome: 'Densidade da Rede', valor: densidade, classificacao: this.classificar(densidade, [0.5, 0.2], ['Alta', 'Média', 'Baixa']) },
            { nome: 'Modularidade Técnica', valor: modularidade, classificacao: this.classificar(modularidade, [0.7, 0.4], ['Alta', 'Média', 'Baixa']) }
          ];

          if (i > 0) {
            const modeloAnterior = this.modelosAnalisados[i - 1];
            const reusabilidade = calcularReusabilidade(
              modeloAnterior.retencaoAtores.atoresAtuaisSet,
              atoresAtuais
            );
            metricas.push({
              nome: 'Reusabilidade de Componentes',
              valor: `${(reusabilidade * 100).toFixed(2)}%`,
              classificacao: this.classificar(reusabilidade * 100, [70, 40], ['Alta', 'Média', 'Baixa'])
            });
          }

          const componentesPorTipo = {
            'Empresa de Interesse': occurrences(modeloData, "tipo=empresa"),
            'Fornecedor': occurrences(modeloData, "tipo=fornecedor"),
            'Cliente': occurrences(modeloData, "tipo=cliente1"),
            'Cliente do Cliente': occurrences(modeloData, "tipo=cliente2"),
            'Intermediário': occurrences(modeloData, "tipo=intermediario"),
            'Agregador': occurrences(modeloData, "tipo=agregador"),
          };

          this.modelosAnalisados.push({
            ...atualModelo,
            modeloData,
            analise,
            retencaoAtores,
            metricas,
            nAtores,
            nRelacionamentos,
            componentes: Array.from(atoresAtuais).map(ator => ({ id: ator })),
            componentesPorTipo
          });
        }

        if (this.modelosAnalisados.length > 1) {
          const anterior = this.modelosAnalisados[0];
          const atual = this.modelosAnalisados[1];
          const componentesV1 = anterior.nAtores || 0;
          const componentesV2 = atual.nAtores || 0;
          const relV1 = anterior.nRelacionamentos || 0;
          const relV2 = atual.nRelacionamentos || 0;

          atual.metricasCalculo = atual.metricasCalculo || {};
          atual.metricasCalculo.variacaoComponentes = componentesV2 - componentesV1;
          atual.metricasCalculo.variacaoRelPercentual = relV1 ? ((relV2 - relV1) / relV1 * 100) : 0;
          atual.metricasCalculo.mediaComponentes = ((componentesV1 + componentesV2) / 2);
          atual.metricasCalculo.mediaRelacionamentos = ((relV1 + relV2) / 2);
        }
      },
      calcularRetencao(atoresAnteriores, atoresRetidos) {
        if (!atoresAnteriores || atoresAnteriores <= 0) return 0;
        return parseFloat(((atoresRetidos / atoresAnteriores) * 100).toFixed(2));
      },
      gerarComparacaoEndToEnd(modelos) {
        if (!modelos || modelos.length < 2) return [];
        return [
          {
            numerico: [],
            percentual: [],
            media: [],
            name: 'Exemplo'
          }
        ];
      },
      extrairDadosMetricas(metrica) {
        const header = ['Modelo', 'Valor', { role: 'annotation', type: 'string' }];
        const data = this.modelosAnalisados.map((modelo) => {
          let valor = modelo.metricasCalculo?.[metrica];
          if (typeof valor === 'string' && valor.includes('%')) {
            valor = parseFloat(valor.replace('%', ''));
          }
          const val = parseFloat(valor || 0).toFixed(2);
          return [modelo.titulo, parseFloat(val), val + ''];
        });
        return [header, ...data];
      },
      gerarOpcoesGrafico(titulo) {
        return {
          title: titulo,
          chartArea: { width: '80%' },
          hAxis: { title: 'Métrica' },
          vAxis: { title: 'Valor' },
          legend: { position: 'none' },
          width: 900,
          height: 500
        }
      }
    },
    created() {
      this.getModelos();
    }
  };
</script>

<style scoped>
#saude {
  width: 100%;
  padding: 24px;
  min-height: 90vh;
  background-color: #ffffff;
  display: flex;
  flex-direction: column;
  gap: 16px;
  overflow-y: auto;
}

#saude .container {
  display: flex;
  flex-direction: column;
  gap: 24px;
  width: 100%;
  padding-bottom: 24px;
}

.v-btn {
  justify-content: center;
}

h1 {
  font-size: 1.6rem;
  font-weight: 600;
  margin-bottom: 16px;
}

.v-expansion-panel-header h2 {
  font-size: 1.2rem;
  margin: 0;
}

.saude-modelo-imagem,
.saude-modelo-chart {
  width: 100%;
  padding: 16px;
  display: flex;
  justify-content: center;
  background-color: #fafafa;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  margin-bottom: 16px;
}

.saude-modelo-imagem img {
  max-width: 100%;
  height: auto;
  object-fit: contain;
}

.saude-modelo-tabela {
  margin: 16px 0;
  background-color: #fafafa;
  padding: 16px;
  border-radius: 4px;
  border: 1px solid #e0e0e0;
}

.selection-checkbox {
  margin: 0 auto;
  padding: 0;
}

.v-card {
  transition: all 0.2s ease-in-out;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  background-color: #fff;
}

.v-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 6px 12px rgba(0, 0, 0, 0.1);
}

.v-container {
  padding: 0;
}

.v-pagination {
  align-self: center;
}

.comparacao-componentes {
  margin: 24px 0;
  padding: 16px;
  background-color: #fafafa;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
}

.comparacao-componentes h3 {
  font-size: 1.2rem;
  margin-bottom: 16px;
  color: #333;
}
</style>