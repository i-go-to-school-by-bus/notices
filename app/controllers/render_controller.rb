class RenderController < ApplicationController
  def index
    @error = false
    if Lastupdated.first.lastupdated < Date.today
      Notice.where("date < ?", 6.months.ago).each do |k|
        k.delete
      end
      DISTRICTS.each_with_index do |k, i|
        if update(i) != 0
          puts "UPDATE RET 1"
          @error = true
        end
      end
      l = Lastupdated.first
      l.lastupdated = Date.today
      l.save
    end
    if !@error
      @lastupdated = Lastupdated.first.lastupdated
      @entries = []
      (0..(DISTRICTS.length - 1)).each do |i|
        @entries.append Notice.where(from: i)
      end
    end
    p @entries
  end

  def update(from)
    if DISTRICTS[from] != nil
      if (DISTRICTS[from][1] == "")
        # add a dummy entry
        add_dummy("support for notices from this source not yet added", from)
        return 0
      end
      res = Curl.get(DISTRICTS[from][1]) {|http|
        http.timeout = 10 # raise exception if request/response not handled within 10 seconds
      }
      if res.code == 200
        if (DISTRICTS[from][3])
          text = res.body.force_encoding('BIG5').encode('UTF-8', invalid: :replace, undef: :replace, replace: "")
        else
          text = res.body
        end
        document = Nokogiri::HTML.parse(text) do |cfg| cfg.noblanks end

        send(DISTRICTS[from][2], document, from)

        if Notice.where(from: from) == nil
          add_dummy("no notices from this source from the past six months", from)
        end
        return 0
      else
        puts "err: #{res.code}"
      end
    end
    return 1
  end

  def update_hkir(document, districtid)
    document.css('tr[data-cat=""]').each do |i|
      n = Notice.new
      n.from = districtid
      n.date = i.element_children[0].inner_text.strip.sub!("年", "-").sub!("月", "-").sub!("日", "")
      n.title = i.element_children[2].inner_text
      n.source = i.element_children[2].css("a")[0][:href]

      attempt_save(n)
    end
  end

  def update_smd(document, districtid)
    document.css("div.entrytext > table > tbody > tr").each do |x|
      n = Notice.new
      n.title = x.element_children[1].inner_text
      n.date = x.element_children[2].inner_text
      n.source = x.element_children[3].element_children[0]["href"]
      n.from = districtid

      attempt_save n
    end
  end

  def update_tko(document, districtid)
    document.css("div.divlink > div.form-group").each do |x|
      n = Notice.new

      n.date = "01-#{x.element_children[0].inner_text}"
      n.title = x.element_children[1].inner_text
      n.source = "https://hkscout-tko.org/notice/?nid=#{x.element_children[2].element_children[0]["data-id"]}"
      if x.element_children[3].element_children[0]["class"] == "span_expired"
        n.duedate = "01-01-1970"
      else
        n.duedate = x.element_children[3].element_children[0].inner_text.sub!("截止: ", "")
      end
      n.from = districtid

      attempt_save n
    end
  end

  def dummy(unused1, unused2)

  end

  def attempt_save(n)
    if n.date > 6.months.ago && Notice.where(source: n.source)[0] == nil
      n.save
    end
  end

  def add_dummy(message, districtid)
    n = Notice.new
    n.title = message
    n.from = districtid
    n.source = "https://piped.garudalinux.org/watch?v=J-jrqxT5kKE"
    n.date = "1970-1-1"
    n.duedate = "1970-1-1"
    n.save
  end
end
