class RenderController < ApplicationController
  def index
    if Lastupdated.first.lastupdated < DateTime.current.at_beginning_of_day
      Notice.where("date < ?", 6.months.ago).each do |k|
        k.delete
      end
      DISTRICTS.each_with_index do |k, i|
        update(i)
      end
      l = Lastupdated.first
      l.lastupdated = DateTime.current
      l.save
    end
    @lastupdated = Lastupdated.first.lastupdated
    @entries = []
    (0..(DISTRICTS.length - 1)).each do |i|
      @entries.append Notice.where(from: i).order(date: :desc)
    end
  end

  def update(from)
    url_list = []
    if DISTRICTS[from] == nil
      return
    end
    if (DISTRICTS[from][5] == nil && DISTRICTS[from][1] == "")
      # add a dummy entry
      add_dummy("support for notices from this source not yet added", from)
      return
    end
    if DISTRICTS[from][5] != nil
      url_list = send(DISTRICTS[from][5])
    else
      url_list.append DISTRICTS[from][1]
    end
    url_list.each do |url|
      if (DISTRICTS[from][4])
        puts ("phantom_getting #{from}")
        text = phantom_get(url, from)
      else
        puts ("curl_getting #{from}")
        text = curl_get(url, from)
      end
      if !text
        return
      end
      document = Nokogiri::HTML.parse(text) do |cfg| cfg.noblanks end
      send(DISTRICTS[from][2], document, from)
    end
    if Notice.where(from: from).length == 0
      add_dummy("no notices from this source from the past six months", from)
    end
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

  def update_hkn(document, districtid)
    document.css("thead > tr, tbody > tr").drop(1).each do |x|
      n = Notice.new
      n.extralinks = ""
      n.from = districtid
      n.title = x.element_children[0].element_children[0].inner_text
      x.element_children[0].xpath('./text()').each do |str|
        n.title += str
      end
      n.date = "2112-09-03"
      n.source = x.element_children[0].element_children[0]["href"]
      n.duedate = x.element_children[3].inner_text
      n.extralinks += "活動日期: #{x.element_children[2].inner_text.gsub("\n", "")}\n#\n"
      x.element_children[0].css("a").drop(1).each do |l|
        n.extralinks += "#{l.inner_text.gsub("\n", "")}\n"
        n.extralinks += "#{l["href"]}\n"
      end
      attempt_save n
    end
  end

  def update_vic(document, districtid)
    a = []
	  document.css('.JNdkSc-SmKAyb.LkDMRd').each do |x|
	  	if x.inner_text.strip != ""
	  		a.append x
	  	end
	  end
	  a.drop(1).each do |x|
      n = Notice.new
      n.from = districtid
	  	x = x.element_children[0]
	  	n.date = x.css("h3")[0].inner_text.strip
	  	node = x.css("h3")[0].next
	  	while node.inner_text.strip == ""
	  		node = node.next
	  	end
	  	n.title = node.inner_text
	  	n.source = nil
	  	x.css("a").each do |link|
	  		if link["href"][0] != '#'
	  			n.source = link["href"]
	  		end
	  	end
	  	duedatenode = node
	  	while node.next != nil
	  		node = node.next
	  		if node.inner_text.strip != ""
	  			duedatenode = node
	  		end
	  	end
	  	if duedatenode.inner_text.index("年") == nil || duedatenode.inner_text.index("月") == nil || duedatenode.inner_text.index("日") == nil
	  		n.duedate = nil
	  	else
        datestr = duedatenode.inner_text.sub("截止日期", "").sub(':', "").sub("年", "-").sub("月", "-").sub("日", "").strip
	  		datestr = datestr.strip.slice(0..(datestr.index('(') - 1)).strip
        n.duedate = datestr
	  	end
      attempt_save n
	  end
  end

  def hkw_urls
    arr = []
    arr.append "https://group.scout.org.hk/hkw/circular/circular#{Date.current.year}/"
    arr.append "https://group.scout.org.hk/hkw/circular/circular#{Date.current.last_year.year}/"
    return arr
  end

  def update_hkw(document, districtid)
    document.css("tbody > tr").drop(1).each do |x|
      n = Notice.new
      n.date = x.element_children[0].inner_text.sub("年", "-").sub("月", "-").sub("日", "")
      n.title = x.element_children[1].element_children[0].inner_text
      n.source = x.element_children[1].element_children[0]["href"]
      n.from = districtid
      attempt_save n
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

  def update_hks(document, districtid)
    document.css(".hJDwNd-AhqUyc-wNfPc.Ft7HRd-AhqUyc-wNfPc.purZT-AhqUyc-II5mzb.ZcASvf-AhqUyc-II5mzb.pSzOP-AhqUyc-wNfPc.Ktthjf-AhqUyc-wNfPc.JNdkSc.SQVYQc.yYI8W.HQwdzb").each do |x|
      n = Notice.new
      n.from = districtid
      n.date = "2112-09-03"
      n.title = x.inner_text
      n.title = n.title.slice((n.title.index("活動名稱：") + 5)..(n.title.index("活動日期：") - 1))
      n.source = x.css("a")[0]["href"]
      ddstr = x.inner_text
      ddstr = ddstr.slice((ddstr.index("截止日期：") + 5)..(ddstr.length))
      ddstr = ddstr.slice(0..(ddstr.index("(") - 1))
      ddstr = ddstr.sub(':', "").sub("年", "-").sub("月", "-").sub("日", "")
      n.duedate = ddstr

      n.extralinks = ""
      elnode = x.css("a")
      (1..(elnode.length - 1)).each do |el|
        n.extralinks += "#{elnode[el].inner_text.gsub("/n", "").strip}\n#{elnode[el]["href"]}\n"
      end
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

  def update_ytd(document, districtid)
    document.css("tbody")[4].css("a").each do |x|
		  if x["href"] == "S01%20Scout%20Membership%20Badge%20Record.xls"
		  	break
		  end
      n = Notice.new
      n.from = districtid
		  n.date = "2112-09-03"
		  n.title = x.inner_text
		  n.source = "http://www.krscout.hk/yautsim/#{x["href"]}"
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

  def ntr_urls
    arr = []
    arr.append "https://www.scout-ntr.org.hk/mainweb/big5/circulars/youth.php?year=#{Date.current.year}"
    arr.append "https://www.scout-ntr.org.hk/mainweb/big5/circulars/youth.php?year=#{Date.current.last_year.year}"
    return arr
  end

  def update_ntr(document, districtid)
    a = []
	  document.css("div.contentArea tr").each do |k|
	  	if k.css("td.table2Content").length > 0
	  		a.append k
	  	end
	  end
	  a.each do |x|
      n = Notice.new
	  	n.date = x.element_children[0].inner_text.sub("年", "-").sub("月", "-").sub("日", "")
	  	n.title = x.element_children[1].css("a")[0].inner_text
	  	n.source = x.element_children[1].css("a")[0]["href"]
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

  def update_tmw(document, districtid)
    p = document.css("tr")
    # ignore the last three entries because they are forms and not notices
    p.slice(0..(p.length-4)).each do |x|
      n = Notice.new
      n.date = x.element_children[0].inner_text
      n.title = ""
      n.extralinks = ""
      n.from = districtid
      tmp = x.element_children[1].element_children
      i = 0
      (0..(tmp.length - 1)).each do |i0|
        i = i0
        if tmp[i].name == "br"
          break
        end
        n.title += tmp[i].inner_text
      end
      n.title = n.title.strip.gsub("\n", "")
      if x.css("a")[1] == nil
        n.source = "https://tmw.scout-ntr.org.hk/#{x.css("a")[0]["href"]}"
      else
        n.source = "https://tmw.scout-ntr.org.hk/#{x.css("a")[1]["href"]}"
      end
      #the link with the first source should be at i-1 now
      this_link = ""
      this_title = ""
      reading = false
      ((i+1)..(tmp.length-1)).each do |j|
        if tmp[j].name == "br" && this_link != "" && this_title != ""
          this_link = this_link.gsub("\r", "\n").gsub("\n", "").strip
          this_title = this_title.gsub("\r", "\n").gsub("\n", "").strip
          n.extralinks += "#{this_title}\n#{this_link}\n"
          this_link = ""
          this_title = ""
          reading = false
          next
        end
        if tmp[j].name == "a" && this_link == ""
          if reading
            this_link = "https://tmw.scout-ntr.org.hk/#{tmp[j]["href"]}"
          else
            # why does the pointing fingers have a link????!?!?!?!?!
            reading = true
          end
        end
        this_title += tmp[j].inner_text
      end
      if n.extralinks == ""
        n.extralinks = nil
      end
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

  def update_tpn(document, districtid)
    a = []
    lists = document.css(".elementor-tab-content.elementor-clearfix ul")
    lists[0].element_children.each do |x|
      a.append x
    end
    lists[1].element_children.each do |x|
      a.append x
    end
    a.each do |x|
      x = x.element_children[0]
      n = Notice.new
      n.date = "2112-09-03"
      n.title = x.inner_text
      n.source = x["href"]
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
    if n.duedate != nil && n.duedate < Date.current.last_year
      return
    end
    if n.date > 6.months.ago && Notice.where(source: n.source)[0] == nil
      n.save
    end
  end

  def add_dummy(message, districtid)
    n = Notice.new
    n.title = message
    n.from = districtid
    n.source = "https://piped.video/watch?v=J-jrqxT5kKE"
    n.date = "1970-1-1"
    n.duedate = "1970-1-1"
    if Notice.where(from: n.from)[0] == nil
      n.save
    end
  end

  def curl_get(url, from)
    res = Curl.get(url) {|http|
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
      #puts "headers:"
      #puts res.head
      #puts "end headers"
      #puts "response: "
      #puts res.body
      #puts "end response"
      Notice.where(from: from).each do |x|
        x.delete
      end
      add_dummy("attempt to update notices from this source encountered an error: #{res.code}", from)
    end
    return nil
  end

  def phantom_get(url, from)
    filename = "/tmp/SCRIPT.js"
    jscode =
    "
    /**
     * This is a project designed to get around sites using Cloudflare's 'I'm under attack' mode.
     * Using the PhantomJS headless browser, it queries a site given to it as the second parameter,
     *  waits six seconds and returns the cookies required to continue using this site.  With this,
     *  it is possible to automate scrapers or spiders that would otherwise be thwarted by Cloudflare's
     *  anti-bot protection.
     *
     * To run this: phantomjs cloudflare-challenge.js http://www.example.org/
     *
     * Copyright © 2015 by Alex Wilson <antoligy@antoligy.com>
     *
     * Permission to use, copy, modify, and/or distribute this software for
     * any purpose with or without fee is hereby granted, provided that the
     * above copyright notice and this permission notice appear in all
     * copies.
     *
     * THE SOFTWARE IS PROVIDED 'AS IS' AND ISC DISCLAIMS ALL WARRANTIES WITH
     * REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
     * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL ISC BE LIABLE FOR ANY
     * SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
     * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
     * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
     * OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
     */


    /**
     * Namespaced object.
     * @type {Object}
     */
    var antoligy = antoligy || {};

    /**
     * Simple wrapper to retrieve Cloudflare's 'solved' cookie.
     * @type {Object}
     */
    antoligy.cloudflareChallenge = {

    	webpage:	false,
    	system:		false,
    	page:		false,
    	url:		false,
    	userAgent:	false,

    	/**
    	 * Initiate object.
    	 */
    	init: function() {
    		this.webpage	= require('webpage');
    		this.system		= require('system');
    		this.page		= this.webpage.create();
    		this.url		= '#{url}';
    		this.userAgent	= 'Mozilla/5.0 (Windows NT 6.3; rv:36.0) Gecko/20100101 Firefox/36.0';
    		this.timeout	= 6000;
    	},

    	/**
    	 * Solve' Cloudflare's challenge using PhantomJS's engine.
    	 * @return {String} JSON containing our cookies.
    	 */
    	solve: function() {
    		var self = this;
    		this.page.settings.userAgent = this.userAgent;
    		this.page.open(this.url, function(status) {
    			setTimeout(function() {
    				console.log(self.page.content);
    				phantom.exit()
    			}, self.timeout);
    		});
    	}

    }

    /**
     * In order to carry on making requests, both user agent and IP address must what is returned here.
     */
    antoligy.cloudflareChallenge.init();
    antoligy.cloudflareChallenge.solve();
    "
    File.write(filename, jscode)
    text = Phantomjs.run(filename)
    if (DISTRICTS[from][3])
      return text.force_encoding('BIG5').encode('UTF-8', invalid: :replace, undef: :replace, replace: "")
    else
      return text.force_encoding('UTF-8')
    end
  end
end
