
local package = require("package")

package.loaded["level_maintainer.ae2"] = nil
package.loaded["level_maintainer.logging"] = nil
package.loaded["level_maintainer.utils"] = nil

local event = require("event")
local component = require("component")

local logging = require("level_maintainer.logging")
local utils = require("level_maintainer.utils")

local cfg = utils.load("/etc/level-maintainer/levels.cfg")

local logger = logging({
    app_name = "maintainer",
})

local iface = component.me_interface

function get_active_crafts()
    local items = {}

    for _, cpu in pairs(iface.getCpus()) do
        local output = cpu.cpu.finalOutput()

        if output then
            items[output.label] = true
        end
    end

    return items
end

::start::

local crafts = get_active_crafts()

for item, config in pairs(cfg.items) do
    if not crafts[item] then
        local craftable = iface.getCraftables({ label = item })[1]
    
        if not craftable then
            logger.error("Missing Pattern: " .. item)
            goto continue
        end
    
        local result = craftable.getItemStack()
    
        if result.label ~= item then goto continue end
    
        if config.threshold ~= nil then
            local stored = iface.getItemsInNetwork({ label = item })
    
            if #stored > 0 and stored[1].size > config.threshold then goto continue end
        end
    
        local craft = craftable.request(config.batch, config.cpu and true or false, config.cpu)
    
        logger.info("Calculating craft for " .. result.label .. " x " .. utils.format_int(config.batch))
    
        while craft.isComputing() do
            if event.pull(1, "interrupted") then
                logger.info("interrupted")
                return
            end
        end
    
        if craft.hasFailed() then
            logger.error("Could not calculate craft for " .. result.label .. " x " .. utils.format_int(config.batch))
        else
            logger.info("Started craft for " .. result.label .. " x " .. utils.format_int(config.batch))
        end
    end

    ::continue::
end

if event.pull(cfg.interval, "interrupted") then
    logger.info("interrupted")
    return
end

goto start
