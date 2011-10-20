#!/usr/bin/env ruby
#totales.csv 
#k=%w{cod_eleccion cod_distrito cod_seccion nombre_lugar mesas_totales mesas_escrutadas mesas_escrutadas_pct electores total_votantes participacion_sobre_censo participacion_sobre_escrutado electores_escrutados electores_escrutados_pct votos_validos votos_validos_pct votos_positivos votos_positivos_pct votos_blanco votos_blanco_pct votos_nulos votos_nulos_pct votos_impugnados votos_impugnados_pct }

require "set"
dir = ARGV[0] || raise("use #{$0} dir output_dir")
output_dir = ARGV[1] || raise("use #{$0} dir output_dir")
timestamp = Time.now

def parse(fd,k)
  ret = []
  while not fd.eof? do
    l=fd.readline
    parts = l.split(";")
    parts.pop
    if parts.length != k.length
      STDERR.write("Warn! expected #{k.length} got #{parts.length}")
      next
    end
    ret << Hash[k.zip(parts.map(&:strip))]
  end
  ret
end
codigos_elecciones = {
  "1" => "Presidente", 
  "2" => "Senadores Nacionales",
  "3" => "Diputados Nacionales",
  "4" => "Gobernador",
  "5" => "Senadores Provinciales",
  "6" => "Diputados Provinciales",
}

totallistas = parse(open(dir + "/totaleslistas.csv","r:ISO8859-1"), %w{cod_eleccion cod_distrito cod_seccion nombre_lugar dia hora minuto cod_agrupacion votos_agrupacion votos_agrupacion_pct cargos_electos} + 10.times.map.with_index{|i| ["cod_lista_#{i}", "votos_lista_#{i}", "votos_lista_pct_#{i}", ]}.flatten)

listas = parse(open(dir + "/listas.csv","r:ISO8859-1"), %w{cod_agrupacion sigla_agrupacion denominacion_agrupacion})

output=Hash.new{|h,k| h[k]=[] }
output_trans=Hash.new{|h,k| h[k]=Hash.new{|h2,k2| h2[k2] = Hash.new{|h3,k3| h3[k3] = []}} }
eleccion_agrupaciones=Hash.new{|h,k| h[k]=Set.new }

totallistas.each{|d|
  next if d["cod_distrito"] == "999" or d["cod_seccion"] == "999" 
  lista = listas.find{|l| 
    l.fetch("cod_agrupacion") == d.fetch("cod_agrupacion")
  }
  if not lista
    STDERR.write("No encuentro la agrupacion '#{d["cod_agrupacion"]}'\n")
    next
  end
  val = d.dup
  val["votos_agrupacion"] = val["votos_agrupacion"].to_i
  val["votos_agrupacion_pct"] = "#{val["votos_agrupacion_pct"].to_f / 100}"
  10.times{|i|
    val["votos_lista_#{i}"] = val["votos_lista_#{i}"].to_i 
    val["votos_lista_pct_#{i}"] = "#{val["votos_lista_pct_#{i}"].to_f / 100}" 
  }
  output[d["cod_eleccion"]] << [ lista.fetch("denominacion_agrupacion"), d.fetch("cod_distrito") + d.fetch("cod_seccion") ] + val.values 
  output_trans[d["cod_eleccion"]][d.fetch("cod_distrito") + d.fetch("cod_seccion")][lista.fetch("denominacion_agrupacion")]=val["votos_agrupacion"]
  eleccion_agrupaciones[d["cod_eleccion"]] << lista.fetch("denominacion_agrupacion")
}

header = ["fecha carga","lista","distrito-seccion" ] + totallistas.first.keys
codigos_elecciones.each{|cod_eleccion,name|
  open(output_dir + "/#{name}.csv", "w:UTF-8"){|fd|
    fd.write(header.join(",") + "\n")
    output[cod_eleccion].each{|d|
      fd.write(([timestamp] + d).join(",") + "\n")
    }
  }
  agrupaciones = eleccion_agrupaciones[cod_eleccion].to_a.sort
  open(output_dir + "/#{name}_traspuesta.csv", "w:UTF-8"){|fd|
    fd.write((["distrito-seccion"] + agrupaciones + ["1ro", "2do", "3ro"] ).join(",") + "\n")
    output_trans[cod_eleccion].each{|distrito_seccion, votos|
      row = [distrito_seccion]
      agrupaciones.each{|agrupacion|
        row << votos[agrupacion]
      }
      # los primeros 3 puestos
      row += votos.sort_by{|agrupacion_votos| 
         agrupacion_votos.last.to_s.to_i # algunos votos son [] (?), así los convierto a 0
        }.reverse[0 ... 3].map(&:first)
      fd.write(row.join(",") + "\n")
    }
  }
}
