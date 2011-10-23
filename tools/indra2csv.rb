#!/usr/bin/env ruby
#totales.csv 
#k=%w{cod_eleccion INDRAProv INDRAdep nombre_lugar mesas_totales mesas_escrutadas mesas_escrutadas_pct electores total_votantes participacion_sobre_censo participacion_sobre_escrutado electores_escrutados electores_escrutados_pct votos_validos votos_validos_pct votos_positivos votos_positivos_pct votos_blanco votos_blanco_pct votos_nulos votos_nulos_pct votos_impugnados votos_impugnados_pct }

def pct2alpha(pct,max=100)
  pct=max if pct > max
  alpha = pct.to_f * 255 / max
  ("0"+alpha.to_i.to_s(16))[-2..-1]
end

require "set"
dir = ARGV[0] || raise("use #{$0} dir output_dir")
output_dir = ARGV[1] || raise("use #{$0} dir output_dir")
timestamp = Time.now
mapa_colores =  {"0131"=>"#1c70b6", "0047"=>"#6cb741", "0137"=>"#a9261c", "0132"=>"#9435f3", "0133"=>"#ffff99", "0134"=>"#fe742c", "0135"=>"#999966"} 

def parse(fd,k)
  ret = []
  while not fd.eof? do
    l=fd.readline
    parts = l.split(";")
    parts.pop if l.end_with?(";")
    if parts.length != k.length
      STDERR.write("#{fd.path} Warn ! expected #{k.length}keys got #{parts.length}\n")
    end
    ret << Hash[k.zip(parts.map(&:strip))]
  end
  ret
end
codigos_elecciones = {
  "1" => "presidente", 
  "2" => "senadores_nacionales",
  "3" => "diputados_nacionales",
  "4" => "gobernador",
  "5" => "senadores_provinciales",
  "6" => "diputados_provinciales",
}

totallistas = parse(open(dir + "/totaleslistas.csv","r:ISO8859-1"), %w{cod_eleccion INDRAProv INDRAdep nombre_lugar dia hora minuto cod_agrupacion votos_agrupacion votos_agrupacion_pct cargos_electos} + 10.times.map.with_index{|i| ["cod_lista_#{i}", "votos_lista_#{i}", "votos_lista_pct_#{i}", ]}.flatten)

listas = parse(open(dir + "/listas.csv","r:ISO8859-1"), %w{cod_agrupacion sigla_agrupacion denominacion_agrupacion})

totales = parse(open(dir + "/totales.csv","r:ISO8859-1"),  %w{cod_eleccion INDRAProv INDRAdep nombre_lugar mesas_totales mesas_escrutadas mesas_escrutadas_pct electores total_votantes participacion_sobre_censo participacion_sobre_escrutado electores_escrutados  electores_escrutados_pct votos_validos votos_validos_pct votos_positivos votos_positivos_pct votos_en_blanco votos_en_blanco_pct votos_nulos votos_nulos_pct votos_recurridos_e_impugnados votos_recurridos_e_impugnados_pct cargos_a_elegir dia hora minuto } )

output=Hash.new{|h,k| h[k]=[] }
resultados_por_provincia=Hash.new{|h,k| h[k]=[] }
output_trans=Hash.new{|h,k| h[k]=Hash.new{|h2,k2| h2[k2] = Hash.new{|h3,k3| h3[k3] = {}}} }
output_totales=Hash.new{|h,k| h[k]=[] }
eleccion_agrupaciones=Hash.new{|h,k| h[k]=Set.new }

ganador_distrito = Hash.new{|h,k| h[k]=[] } 

#
# totaleslistas.csv
#
totallistas.each{|d|
  next if  d["INDRAProv"] == "999"  
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
  row = [ lista.fetch("denominacion_agrupacion"), d.fetch("INDRAProv") + d.fetch("INDRAdep") ] + val.values 
  if d["INDRAdep"] == "999" 
    resultados_por_provincia[d["cod_eleccion"]] << row
  else
    output[d["cod_eleccion"]] << row
    output_trans[d["cod_eleccion"]][d.fetch("INDRAProv") + d.fetch("INDRAdep")][lista.fetch("denominacion_agrupacion")]=val
    eleccion_agrupaciones[d["cod_eleccion"]] << lista.fetch("denominacion_agrupacion")
  end
}

# 
# CSVs por codigo de eleccion
#
header = ["fecha carga","lista","INDRA" ] + totallistas.first.keys
codigos_elecciones.each{|cod_eleccion,name|
  open(output_dir + "/#{name}.csv", "w:UTF-8"){|fd|
    fd.write(header.join(",") + "\n")
    output[cod_eleccion].each{|d|
      fd.write(([timestamp] + d).join(",") + "\n")
    }
  }
  agrupaciones = eleccion_agrupaciones[cod_eleccion].to_a.sort
  open(output_dir + "/#{name}_traspuesta.csv", "w:UTF-8"){|fd|
    fd.write((["INDRA"] + agrupaciones + ["color_primero","1ro", "2do", "3ro"]  ).join(",") + "\n")
    output_trans[cod_eleccion].each{|distrito_seccion, votos|
      row = [distrito_seccion]
      agrupaciones.each{|agrupacion|
        row << votos[agrupacion]["votos_agrupacion_pct"]
      }
      # los primeros 3 puestos
      top3 = votos.sort_by{|agrupacion,values| 
         values["votos_agrupacion_pct"].to_s.to_i # algunos votos son [] (?), así los convierto a 0
        }.reverse[0 ... 3]
      if top3.first #color
        agrupacion, values =top3.first
        if mapa_colores[values["cod_agrupacion"]]
          row << mapa_colores[values["cod_agrupacion"]] + pct2alpha(values["votos_agrupacion_pct"].to_f,86)
        end
      end
      row += top3.map{|agrupacion,values| agrupacion}
      fd.write(row.join(",") + "\n")
      if top3.first and cod_eleccion == "1" #solo para presidente
        ganador = top3.first
        ganador_distrito[ganador.first] << [distrito_seccion,ganador.last]
      end
    }
  }
}

# 
# CSVs por codigo de eleccion totalizada por provincia
#
header = ["fecha carga","lista","INDRA" ] + totallistas.first.keys
codigos_elecciones.each{|cod_eleccion,name|
  open(output_dir + "/#{name}_totales_por_provincia.csv", "w:UTF-8"){|fd|
    fd.write(header.join(",") + "\n")
    resultados_por_provincia[cod_eleccion].each{|d|
      fd.write(([timestamp] + d).join(",") + "\n")
    }
  }
}

#
# departamentos_ganados.csv
#
ganador_distrito.each{|agrupacion,distritos_votos|
  open(output_dir + "/departamentos_ganados_#{agrupacion}.csv","w:UTF-8"){|fd|
    fd.write(["INDRA","votos_pct"].join(",") + "\n")
    distritos_votos.each{|distrito,votos|
      fd.write([distrito,votos].join(",") + "\n")
    }
  }
}

#
# totales.csv
#

totales.each{|d|
  next if d["INDRAProv"] == "999" or d["INDRAdep"] == "999" 
  val = d.dup
  %w{mesas_escrutadas mesas_totales electores total_votantes participacion_sobre_censo participacion_sobre_escrutado electores_escrutados  votos_validos votos_positivos votos_en_blanco votos_nulos votos_recurridos_e_impugnados }.each{|k|
    val[k] = val[k].to_i
  }
  %w{ mesas_escrutadas_pct electores_escrutados_pct votos_validos_pct votos_positivos_pct votos_en_blanco_pct votos_nulos votos_nulos_pct votos_recurridos_e_impugnados_pct participacion_sobre_censo participacion_sobre_escrutado }.each{|k|
    val[k] = "#{val[k].to_f / 100}"
  }

  output_totales[d["cod_eleccion"]] << [ d.fetch("INDRAProv") + d.fetch("INDRAdep") ] + val.values 
}

header = ["fecha carga","INDRA" ] + totales.first.keys
codigos_elecciones.each{|cod_eleccion,name|
  open(output_dir + "/totales_#{name}.csv", "w:UTF-8"){|fd|
    fd.write(header.join(",") + "\n")
    output_totales[cod_eleccion].each{|d|
      fd.write(([timestamp] + d).join(",") + "\n")
    }
  }
}
