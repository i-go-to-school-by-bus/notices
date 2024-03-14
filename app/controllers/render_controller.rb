class RenderController < ApplicationController
  def index
    @error = false
    if Lastupdated.first.lastupdated < Date.today
      Notice.where("date < ?", 6.months.ago).each do |k|
        k.delete
      end
      DISTRICTS.each_with_index do |k, i|
        if update(i) != 0
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
  end

  def update(from)
    if DISTRICTS[from] == nil
      return 1
    end
    if (DISTRICTS[from][1] == "")
      # add a dummy entry
      add_dummy("support for notices from this source not yet added", from)
      return 0
    end
    if (DISTRICTS[from][4])
      puts ("phantom_getting #{from}")
      text = phantom_get(from)
    else
      puts ("curl_getting #{from}")
      text = curl_get(from)
    end
    document = Nokogiri::HTML.parse(text) do |cfg| cfg.noblanks end
    send(DISTRICTS[from][2], document, from)
    if Notice.where(from: from).length == 0
      add_dummy("no notices from this source from the past six months", from)
    end
    return 0
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

  def update_skw(document, districtid)
    document.css(".posts-wrapper")[0].element_children.each do |x|
      n = Notice.new
      n.date = x.css("time")[0]["content"]
      n.title = x.css(".blog-entry-title.entry-title")[0].inner_text
      n.source = x.css("a")[0]["href"]
      n.from = districtid
      attempt_save n
    end
  end

  def update_cwd(document, districtid)
    document.css(".col.post-item").each do |x|
      n = Notice.new
      x = x.element_children[0].element_children[0]

      n.title = x.css(".post-title.is-large")[0].inner_text
      n.date = x.css(".post-meta")[0].inner_text
      n.source = x["href"]
      n.from = districtid

      attempt_save n
    end
  end

  def update_kr(document, districtid)
  	document.css("tbody")[0].element_children.each do |x|
      n = Notice.new
	  	n.date = x.element_children[0].inner_text
	  	n.title = x.element_children[1].inner_text
	  	n.source = x.element_children[5].element_children[0]["href"]
	  	n.duedate = x.element_children[2].inner_text
      n.from = districtid
	  	if n.duedate == ""
	  		n.duedate = nil
	  	end
      attempt_save n
    end
  end

  def update_klc(document, districtid)
    document.css("div.newsid > div").each do |x|
      n = Notice.new

      n.date = x.element_children[0].inner_text
      n.title = x.element_children[2].inner_text
      n.source = x.element_children[4].element_children[0]["href"]
      n.from = districtid

      attempt_save n
    end
  end

  def update_klg(document, districtid)
    document.css("tr.oddrow, tr.evenrow").each do |x|
      n = Notice.new
      n.date = x.element_children[0].inner_text
      n.title = x.element_children[3].element_children[0].inner_text
      n.source = x.element_children[3].element_children[0]["href"]
      n.duedate = x.element_children[2].inner_text
      n.from = districtid
      if n.duedate == ""
        n.duedate = nil
      end
      attempt_save n
    end
  end

  def update_mkd(document, districtid)
    document.css("#recent-posts-2 > ul > li").each do |x|
      n = Notice.new
	  	n.date = x.element_children[1].inner_text.sub!(" 年 ", "-").sub!(" 月 ", "-").sub!(" 日", "").strip
	  	n.title = x.element_children[0].inner_text
	  	n.source = x.element_children[0]["href"]
      n.from = districtid

      attempt_save n
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

  def update_ekr(document, districtid)
    document.css(".w3eden").each do |x|
      x = x.css(".media")[0]
      n = Notice.new

      n.date = x.css(".p-0").inner_text.sub("上載日期:", "").strip
      n.title = x.css(".media-heading")[0].inner_text
      n.source = "https://hkscout-ekr.org/#{x.css(".wpdm-download-link")[0]["href"]}"
      n.from = districtid

      attempt_save n
    end
  end

  def update_wts(document, districtid)
    document.css("tbody > tr").each do |x|
      n = Notice.new
      n.date = x.element_children[0].inner_text.sub("年", "-").sub("月", "-").sub("日", "").sub(" ", "")
      n.title = x.element_children[1].inner_text
      n.source = x.element_children[5].element_children[0]["href"]
      n.duedate = x.element_children[2].inner_text.sub("年", "-").sub("月", "-").sub("日", "").sub(" ", "")
      n.from = districtid
      if n.duedate == "--"
        n.duedate = nil
      end
      attempt_save n
    end
  end

  def update_skd(document, districtid)
    add_dummy("No notice section present at source", districtid)
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

  def update_yle(document, districtid)
    document.css("tr").drop(1).each do |x|
      n = Notice.new
      n.date = x.element_children[1].inner_text
      n.title = x.element_children[0].inner_text
      n.source = "https://yle.scout-ntr.org.hk/#{x.element_children[2].element_children[0].element_children[0]["href"].sub("file\\", "file/")}"
      n.from = districtid
      attempt_save n
    end
  end

  def update_ylw(document, districtid)
    document.css("article.d-md-flex.mg-posts-sec-post.align-items-center > .mg-sec-top-post.py-3.col").each do |x|
      n = Notice.new

      n.date = x.css(".mg-blog-date > a")[0].inner_text.sub!(" 年 ", "-").sub!(" 月 ", "-").sub!("日", "").strip
      n.title = x.css("h4")[0].element_children[0].inner_text
      n.source = x.css("h4")[0].element_children[0]["href"]
      n.from = districtid
      attempt_save n
    end

  end

  def update_tme(document, districtid)
    document.css("div.feature")[0].element_children[0].element_children.drop(1).each do |x|
      n = Notice.new
      n.date = x.element_children[0].inner_text.sub!("年", "-").sub!("月", "-").sub!("日", "").strip
      n.title = x.element_children[1].inner_text.strip.gsub("\r\n", "")
      n.source = "https://www.tmescout.org.hk/#{x.element_children[3].css("a")[0]["href"]}"
      n.from = districtid

      attempt_save n
    end
  end

  def update_twd(document, districtid)
    document.css("#group_notices table > tbody")[0].element_children.each do |x|
      n = Notice.new
      n.date = Date.parse(x.element_children[0].inner_text)
      n.title = x.element_children[2].inner_text
      n.source = x.element_children[4].element_children[0]["href"]
      n.from = districtid
      if x.element_children[5].inner_text == "已經結束"
        n.duedate = "1970-01-01"
      end
      attempt_save n
    end
  end

  def update_tyd(document, districtid)
    document.css("table table")[0].element_children.drop(1).each do |x|
      n = Notice.new
      n.date = x.element_children[0].element_children[0].inner_text
      n.title = x.element_children[1].element_children[0].element_children[0].inner_text
      n.source = "https://tyd.scout-ntr.org.hk/#{x.element_children[1].element_children[0].element_children[0]['href']}"
      n.duedate = x.element_children[3].element_children[0].inner_text
      n.from = districtid
      attempt_save n
    end
  end

  def update_tps(document, districtid)
    document.css(".tblContent").each do |x|
      n = Notice.new
      n.date = x.element_children[0].inner_text
      n.title = x.element_children[3].inner_text
      n.source = x.css("a")[0]["href"]
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
    if Notice.where(from: n.from)[0] == nil
      n.save
    end
  end

  def curl_get(from)
    res = Curl.get(DISTRICTS[from][1]) {|http|
      http.timeout = 10 # raise exception if request/response not handled within 10 seconds
    }
    if res.code == 200
      if (DISTRICTS[from][3])
        return res.body.force_encoding('BIG5').encode('UTF-8', invalid: :replace, undef: :replace, replace: "")
      else
        return res.body.force_encoding('UTF-8')
      end
    else
      puts "err: #{DISTRICTS[from][1]} [#{res.code}]"
      puts "headers:"
      puts res.head
      puts "end headers"
      puts "response: "
      puts res.body
      puts "end response"
      return nil
    end
  end

  def phantom_get(from)
    filename = "/tmp/SCRIPT.js"
    jscode =
"     'use strict';
      var page = require('webpage').create(),
          system = require('system'),
          address, delay;
      address = '#{DISTRICTS[from][1]}';
      delay = 10000;
      page.open(address, function (status) {
        if (status !== 'success') {
          console.log('Unable to load the address!');
          phantom.exit(1);
        } else {
          window.setTimeout(function () {
            var content = page.content;
            console.log(content);
            phantom.exit();
          }, delay);
        }
      });"
    File.write(filename, jscode)
    text = Phantomjs.run(filename)
    puts text
    if (DISTRICTS[from][3])
      return text.force_encoding('BIG5').encode('UTF-8', invalid: :replace, undef: :replace, replace: "")
    else
      return text.force_encoding('UTF-8')
    end
  end
end
