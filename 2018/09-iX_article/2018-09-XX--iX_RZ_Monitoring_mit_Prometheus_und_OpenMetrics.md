# Einleitung

Mit Monitoring ist es ein bisschen wie beim Heimwerken: Keiner will einen 8er Bohrer, die Leute wollen ein 8er Loch.
Genauso wird es meist mit der Infrastruktur gehandhabt: Solang alles funktioniert interessiert es kaum warum oder wie lang noch.
Kommt es jedoch zu einem Fehler muss sofort klar sein warum und wie dies zu in Zukunft zu verhindern ist.
Die Kollegen aus dem Vertrieb würden gern auch wissen wie viel Kapazität kurzfristig zur Verfügung steht.
Und für Entscheider ist natürlich auch interessant inwiefern sich Kosten sparen lassen und, falls ja, wie.
All diese Anforderungen haben eins gemein: Die Notwendigkeit frühzeitig Daten zu sammeln, zu speichern und möglichst automatisiert auswertbar zu machen.

Mit Nagios, Zabbix, LibreNMS und anderen existieren schon viele Lösungen, warum also einen Umstieg in Betracht ziehen?

# Prometheus

Um dies zu erklären muss man in die Historie von Prometheus blicken:
Initiiert wurde Prometheus von Exmitarbeitern von Google die zeitgleich zu SoundCloud wechselten und mit Borgmon das vormals geheime Google-interne Monitoring und seine Möglichkeiten vermisst haben.
Da es am Markt nichts Vergleichbares gab entschlossen sie sich kurzerhand, Borgmon in ihrer Freizeit in weiten Teilen nachzubauen: Prometheus war geboren.
Wer sich in der griechischen Mythologie auskennt wird erkennen wie bescheiden der Selbstanspruch dieses Projekts sind, nämlich die Kontrolle über das Feuer den Göttern zu entreissen und den Menschen zur Verfügung zu stellen.
Nachdem innerhalb weniger Jahre mehr als dreihundert Software-Projekte von sich aus ihre Software mit Prometheus kompatibel gemacht haben, so genannte Integrationen, und zehntausende von Firmen mit Prometheus arbeiten ist dieser Selbstanspruch offensichtlich zumindest teilweise erfüllt worden.

Woher kommt dieser Erfolg und wie lässt sich dieser für RZ Betreiber nutzen?

Zuerst ist die konsequente Automatisierung zu nennen.
Prometheus ist von Grund auf darauf ausgelegt komplett automatisiert zu werden.
Das geht über das Hinzufügen von Datenquellen über deren Zuordnung bis hin zur Auswertung der Daten und der Ausleitung von Alarmen.
Über die so genannte Service Discovery können Datenquelle per z.B. per API direkt übergeben werden.
Sind alle Datenquellen sauber im DNS gepflegt kann Prometheus sich die Information über Datenquellen auch einfach er Zonentransfer abholen.
Die meisten Anwender starten aber üblicherweise mit `file_sd`; ein Shell-Skript holt die Quellen in Bestandssystemen ab und schreibt sie in eine Textdatei mit YAML oder JSON, Prometheus erledigt den Rest.
Zum Testen ist diese Textdatei auch von Hand innerhalb von Minuten zu erstellen.

Weiter ist da das Datenmodell: Prometheus speichert Time Series und macht diese über Name und Label Sets verfügbar.
Time Series sind Zeitreihen, also numerische Werte die sich über die Zeit verändern.
Damit kann von Netzwerkdurchsatz über Temperaturen oder Ampere in einem Rack bis hin zum Füllstand des Dieseltanks alles gespeichert werden; Daten die nur als Text vorliegen werden entsprechend in Zahlen umgeschrieben, aus "Battery OK" wird also eine 1, aus "Battery missing" wird eine 0, und so weiter.
Zum jeweiligen Wert speichert Prometheus noch den exakten Zeitpunkt wann der Wert aufgetreten ist.
Diese bewusste Reduktion ermöglicht extremst effiziente Datenspeicherung; die Daten werden auf 1/12 reduziert, die Kompression kostet dabei nur ~3% CPU-Zeit.
Auf einem durchschnittlichen Server lassen sich leicht 100.000 Werte pro Sekunde(!) speichern und das über viele Jahre hinweg.
Auf leistungsstarken Serven sind auch 1.000.000 Werte pro Sekunde kein Problem.

In klassischen Monitoring-Systemen sind Daten hierarchisch abgelegt, also z.B. Land -> Stadt -> Rechenzentrum -> Stockwerk -> Raum -> Cage -> Rack-Reihe -> Rack -> Kunde.
Wenn jetzt ein Kunde ein Rack, der andere Kunde einen Cage mietet wäre dieses System schon an seine Grenzen gekommen.
Schlimmer noch, ein Kunde der sich seine Racks eincagen lässt oder einen zweiten Raum dazu kauft zwingt oft dazu Daten händisch umzusortieren.
Prometheus geht mit den erwähnten Label Sets einen anderen Weg: diese Key-Value-Pairs können an beliebige Time Series angehängt werden, `site="SDC"`, `rack="123"`, und `customer="4711"` sind also gleichberechtigt mit den jeweiligen Daten verknüpft.
Die Namen und Label Sets bauen also dynamisch eine n-dimensionale Matrix auf aus der beliebig selektiert werden kann.

Damit sind wir auch schon beim nächsten Vorteil von Prometheus, der Abfragesprache PromQL.
Bei PromQL handelt es sich um eine turing-vollständige, funktionale Sprache für Vektormathematik mit mehr oder weniger magischem Label Matching die speziell für Prometheus entwickelt wurde.
Die Sprache ist also sehr mächtig aber trotzdem sehr kompakt zu schreiben.
Ein Vektor ist eine Aneinanderreihung von Daten, eine Time Series lässt sich also als Vektor begreifen.
Vektormathematik erlaubt es Formeln zu schreiben bei denen es egal ist ob mit Einzelwerten oder hunderttausenden von Datenpunkten gearbeitet wird.
Ohne Umwege über Schleifen, Zwischenwerte, oder anderen Konstrukten kann direkt mit den Daten gearbeitet werden.
Meist werden Absolutwerte aus Systemen ausgelesen, PromQL macht mit `rate()` aus den Absolutwerten einfach Verlaufswerte von "X pro Sekunde".
Aus den üblichen Joule aus Stomzählern werden mit `rate(dc_power_consumption_joule[5m])` Watt im Mittel der letzten fünf Minuten, um Verbrauchsdauer erweitert auch kWh zur Abrechnung.
Falls sich die Absolutwerte zB durch Neustart eines Messgeräts auf Null zurücksetzen erkennt PromQL dies und passt die Berechnung entsprechend an womit Ausfiltern oder, schlimmer noch das dem Kunden berechnen, von negativen Verbrauchswerten der Vergangenheit angehören.
Das Label Matching im Hintergrund sorgt dafür, dass die Daten über Label Sets automatisch zu sinnvollen Gruppen zusammengefasst werden.
`sum(rate(dc_power_consumption_joule[5m]))` liefert also den gesamten Stromverbrauch eines RZ Betreibers, `sum(rate(dc_power_consumption_joule{customer="4711"}[5m]))` den Verbrauch des Kunden 4711, und `sum(rate(dc_power_consumption_joule{site="SDC"}[5m]))` den für den Standort SDC.
Es kann aber auch noch nach Labels zusammengefasst werden.
Mit `sum(rate(dc_power_consumption_joule[5m])) by (customer)` bekommt der Benutzer eine Liste aller Kunden, mit `sum(rate(dc_power_consumption_joule{site="SDC"}[5m])) by (customer)` aller Kunden an einem Standort und mit `sum(rate(dc_power_consumption_joule[5m])) by (site,customer)` aufgeschlüsselt nach Kunde und Standort.
Durch die Vektormathematik ist es dabei egal ob der aktuelle Wert, alle Werte, oder ein beliebiger Zeitraum betrachtet werden sollen.
Egal ob der Benutzer sich die Daten von Prometheus als Tabelle oder Graph, oder vielleicht sogar mit anderen Tools wie Grafana anzeigen lässt: Im Hintergrund wird immer PromQL empfangen und JSON ausgeliefert; mit `curl http://127.0.0.1::9090/api/v1/query_range?query=sum(rate(dc_power_consumption_joule[5m]))` können die Daten also beliebig wieder in eigene Tools überführt werden, mit `curl http://127.0.0.1::9090/api/v1/query_range?query=sum(rate(dc_power_consumption_joule[5m]))&start=1535025991.911&end=1535630791.911&step=2419&_=1535630750894` die Werte der letzten Woche zum Zeitpunkt des Erstellung der Artikels und so weiter und so fort.

Nicht nur Datenabfrage und -export, auch die Generierung von neuen Daten funktioniert wieder via PromQL.
Mit so genannten Recording Rules können oft durchgeführte Abfragen vorberechnet abgespeichert werden.
Prometheus führt diese Abfragen eigenständig an sich selbst durch und speichert die Daten wieder als Time Series.
Aus `sum(rate(dc_power_consumption_joule[5m])) by (customer)` wird `customer:dc_power_consumption_watt:sum_5m`.

Alarme funktionieren ähnlich wie Recording Rules; kommen bei einer Abfrage Ergebnisse zurück werden diese zur späteren Auswertung als Time Series gespeichert und ein Alarm wird weitergegeben.
`dc_ups_battery_ok != 1` reicht bereits aus und jede Batterie ist inklusive automatischen Angaben über Standort, USV und so weiter aktiv überwacht; `sum(dc_diesel_liter) by (site) < 1000` ist selbsterklärend.
PromQL kann aber mehr.
`dc_ups_feed_wattage / dc_ups_feed_wattage_total > 0.9` warnt vor wenn ein Feed einer USV mehr als 90% Last hat, `avg_over_time(dc_temperature_celsius{group="cold_aisle"}[5m]) by (site,room,cage,row) < 26 > 20` stellt sicher, dass die Temperaturen im Rahmen bleiben.
Im Echtbetrieb sind harte Werte aber zu unflexibel und es wird empfohlen Time Series für `dc_temperature_lower_warning_celsius`, `dc_temperature_upper_critical_celsius` und so weiter auszuleiten; damit ist es dann auch möglich unterschiedliche Schwellenwerte für bestimmte Orte zu vergeben.
Auch die Berechnung von höchst kritischen Werten wie des Taupunkts[Tau] neben dem Arbeitsplatz des Autors mit den Messwerten eines BME280 gefunkt via ESP32 lässt sich rein in PromQL umsetzen auch wenn dies zugegebenermassen ein bisschen länger dauert.

PromQL kann aber _noch_ mehr.
Eine statische Analyse mit exponentieller Glättung[Exp] via `holt_winters()` erlaubt es Trends von kurz- und langfristigen Schwankungen zu befreien und damit Aussagen über die wirkliche Entwicklung von Messwerten zu treffen.
Und so angenehm es ist zu wissen ob noch mindestens 1000 Liter Diesel pro Site verfügbar sind, mit `predict_linear(dc_diesel_liter[1h], 72 * 3600) < 0` lässt sich auch direkt berechnen ob, basierend auf den Verbrauchswerten der letzten Stunde, noch mindestens Diesel für drei Tage vorhanden ist.
Durch die Zugrundelegung von echten Messwerten sind auch Mehrverbräuche durch eine undichte Leitung oder andere unwahrscheinliche Fälle mit abgedeckt; eine Katastrophe entsteht ja meist durch mehrere Fehler die zusammen kommen.

# OpenMetrics

Wie erwähnt gibt es bereits jetzt über dreihundert Integrationen, im Bereich der klassischen Hersteller, und dazu gehören die Hersteller von RZ Komponenten definitiv, mahlen die Mühlen aber langsamer.
Natürlich existieren bereits heute so genannte Exporter die Daten aus fast beliebigen Formaten in Prometheus Format umschreiben, sei es von SNMP, Modbus, CAN bus oder anderen.
Auch das Umschreiben per eigenem Skript ist nahezu trivial und jedem Leser dieses Artikels bereits jetzt möglich.
Eine Textdatei via HTTP oder HTTPS die folgendes enthält
````
dc_power_consumption_joule{site="SDC",room="201",rack="123"customer="4711"} 123456
dc_power_consumption_joule{site="SDC",room="201",rack="124"customer="4712"} 234567
````
ist zwar minimal aber valides Prometheus Exposition Format.
Trotzdem wäre es wünschenswert direkt Daten aus den Systemen oder der GLT ausleiten zu können.

Hier kommt OpenMetrics ins Spiel.
Der Autor hat auf Basis des Prometheus Exposition Format OpenMetrics[OpenMetrics] ins Leben gerufen um einen offenen Standard zu schaffen der nicht an ein bestimmtes Projekt gebunden ist.
Ziel ist es nicht nur ein RFC zu veröffentlichen, sondern auch Referenzimplemtierungen und eine komplette Test Suite im Kompabilität sicher zu stellen.
Bereits jetzt haben mehrere Firmen und Projekte die Umsetzung von OpenMetrics zugesagt[Adopters], die Hauptarbeit wird allerdings von einem kleineren Kreis getragen; im Wesentlichen von ein paar Prometheus Mitgliedern sowie Google und Uber.
Weiter ist OpenMetrics, so wie Prometheus, unter dem Schirm der CNCF[CNCF] einer Tochter der Linux Foundation organisiert was eine weitreichende Adoption auch von Hardware-Herstellern sicher stellt.



[Prometheus] https://prometheus.io
[Grafana] https://grafana.com/
[Tau] https://de.wikipedia.org/wiki/Taupunkt#Abh%C3%A4ngigkeit_der_Taupunkttemperatur_von_relativer_Luftfeuchtigkeit_und_Lufttemperatur
[Exp] https://de.wikipedia.org/wiki/Exponentielle_Gl%C3%A4ttung
[OpenMetrics] https://github.com/OpenObservability/OpenMetrics/
[Adopters] https://github.com/RichiH/talks/blob/master/2018/08-PromCon_2018/2018-08-10--OpenMetrics/PromCon2018--2018-08-10--OpenMetrics.tex#L209
[CNCF] https://cncf.io